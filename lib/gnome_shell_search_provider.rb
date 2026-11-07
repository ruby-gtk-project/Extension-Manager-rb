# frozen_string_literal: true

require 'adwaita'
require_relative 'manager'

# Exports the extensions.gnome.org manager as a GNOME Shell search provider.
#
# Ported from upstream's src/exm-gnome-shell-search-provider.c plus
# src/org.gnome.Shell.SearchProvider2.xml: upstream feeds that XML through
# gdbus-codegen to get an ExmShellSearchProvider2 skeleton with one signal
# per D-Bus method; there is no gdbus-codegen for Ruby, so this class carries
# the same XML as a plain string and answers the method calls itself through
# Gio::DBusConnection#register_object_with_closures2, which is the Ruby
# bindings' equivalent of connecting signal handlers to that skeleton.
#
# Matching is upstream's extension_matches_terms: case-folded substring
# search over an extension's name, description and uuid, every term
# required to match something. Only extensions with a preferences dialog
# (has_prefs) are offered at all, exactly as upstream's find_matching_results
# filters before matching.
class GnomeShellSearchProvider
  INTERFACE_XML = <<~XML
    <node>
      <interface name='org.gnome.Shell.SearchProvider2'>
        <method name='GetInitialResultSet'>
          <arg type='as' name='Terms' direction='in' />
          <arg type='as' name='Results' direction='out' />
        </method>
        <method name='GetSubsearchResultSet'>
          <arg type='as' name='PreviousResults' direction='in' />
          <arg type='as' name='Terms' direction='in' />
          <arg type='as' name='Results' direction='out' />
        </method>
        <method name='GetResultMetas'>
          <arg type='as' name='Results' direction='in' />
          <arg type='aa{sv}' name='Metas' direction='out' />
        </method>
        <method name='ActivateResult'>
          <arg type='s' name='Result' direction='in' />
          <arg type='as' name='Terms' direction='in' />
          <arg type='u' name='Timestamp' direction='in' />
        </method>
        <method name='LaunchSearch'>
          <arg type='as' name='Terms' direction='in' />
          <arg type='u' name='Timestamp' direction='in' />
        </method>
      </interface>
    </node>
  XML

  INTERFACE_NAME = 'org.gnome.Shell.SearchProvider2'

  # How long upstream's handle_activate_result holds the application open
  # after telling it to open an extension's preferences, so the process is
  # not torn down mid-activation.
  HOLD_SECONDS = 2

  def initialize(application, manager)
    @application = application
    @manager = manager
    @registration_id = nil
  end

  def export(connection, object_path)
    @connection = connection
    @object_path = object_path
    @registration_id = connection.register_object_with_closures2(
      object_path,
      node_info.lookup_interface(INTERFACE_NAME),
      method(:handle_method_call).to_proc,
      nil,
      nil,
    )
  end

  def unexport
    (@connection && @registration_id).then do |registered|
      if registered
        @connection.unregister_object(@registration_id)
        @registration_id = nil
      end
    end
  end

  private

    def node_info = @node_info ||= Gio::DBusNodeInfo.new(INTERFACE_XML)

    def handle_method_call(_connection, _sender, _object_path, _interface_name, method_name, parameters, invocation)
      case method_name
      when 'GetInitialResultSet' then initial_result_set(parameters, invocation)
      when 'GetSubsearchResultSet' then subsearch_result_set(parameters, invocation)
      when 'GetResultMetas' then result_metas(parameters, invocation)
      when 'ActivateResult' then activate_result(parameters, invocation)
      when 'LaunchSearch' then launch_search(parameters, invocation)
      end
    end

    def initial_result_set(parameters, invocation)
      terms, = parameters.to_a
      invocation.return_value(GLib::Variant.parse("(#{printed_string_array(matching_uuids(terms))},)"))
    end

    # The shell narrows an existing search with the same call upstream
    # answers the same way: upstream never actually filters the previous
    # results, it just reruns the match over every extension again.
    def subsearch_result_set(parameters, invocation)
      _previous_results, terms = parameters.to_a
      invocation.return_value(GLib::Variant.parse("(#{printed_string_array(matching_uuids(terms))},)"))
    end

    def result_metas(parameters, invocation)
      results, = parameters.to_a
      metas = results.filter_map { |uuid| printed_meta(uuid) }
      invocation.return_value(GLib::Variant.parse("(#{printed_meta_array(metas)},)"))
    end

    def activate_result(parameters, invocation)
      result, _terms, _timestamp = parameters.to_a
      @manager.by_uuid(result).then do |extension|
        if extension
          @application.hold
          GLib::Timeout.add_seconds(HOLD_SECONDS) do
            @application.release
            false
          end
          @manager.open_prefs(extension)
        end
      end
      invocation.return_value(nil)
    end

    def launch_search(parameters, invocation)
      terms, _timestamp = parameters.to_a
      @application.activate
      @application.active_window&.then do |window|
        window.activate_action('win.search-installed', GLib::Variant.new(terms.join(' ')))
      end
      invocation.return_value(nil)
    end

    def matching_uuids(terms)
      Array.new(@manager.extensions.n_items) { |index| @manager.extensions.get_item(index) }
        .select { |extension| extension.has_prefs && matches_terms?(extension, terms) }
        .map(&:uuid)
    end

    def matches_terms?(extension, terms)
      haystacks = [extension.name, extension.description, extension.uuid].compact.map { |s| s.to_s.downcase }
      terms.all? { |term| haystacks.any? { |haystack| haystack.include?(term.to_s.downcase) } }
    end

    # Builds one "{sv}" dict entry's printed form per field, the way
    # ShellDbusInterface's #print_options builds a{sv} text — the Ruby
    # bindings cannot build this directly as GVariant objects, only infer it
    # from printed form.
    def printed_meta(uuid)
      @manager.by_uuid(uuid)&.then do |extension|
        name = extension.name.to_s.empty? ? uuid : extension.name.to_s
        fields = [
          "'id': <#{uuid.inspect}>",
          "'name': <#{name.inspect}>",
          ("'description': <#{extension.description.to_s.inspect}>" unless extension.description.to_s.empty?),
          "'icon': <#{printed_icon}>",
        ].compact
        "{#{fields.join(', ')}}"
      end
    end

    def printed_meta_array(metas)
      if metas.empty?
        '@aa{sv} []'
      else
        "[#{metas.join(', ')}]"
      end
    end

    def printed_string_array(strings)
      if strings.empty?
        '@as []'
      else
        strings.inspect
      end
    end

    # Upstream's g_themed_icon_new(APP_ID) + g_icon_serialize. The gio2 gem
    # exposes both and hands back the serialized "(sv)" as plain Ruby
    # values, which are printed back into GVariant text here the same way
    # every other field in this meta entry is — the only form the Ruby
    # bindings can turn into a real GVariant inside a dict's "v" slot.
    def printed_icon
      icon_type, names = Gio::ThemedIcon.new(@application.application_id.to_s).serialize
      "(#{icon_type.inspect}, <#{names.inspect}>)"
    end
end
