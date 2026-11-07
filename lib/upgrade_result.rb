# frozen_string_literal: true

require 'adwaita'

# One row of the upgrade assistant's results: what the website says about a
# release, paired with the copy of the extension installed locally.
#
# Ported from upstream's src/exm-upgrade-result.c, whose only read-only
# property is `name` — taken from the local extension when there is one and
# from the web data otherwise, which is what lets the assistant list
# extensions that are installed but no longer published. Registered as a
# real GObject property (upstream's g_param_spec_string("name", ..., NULL,
# G_PARAM_READABLE)), not a plain Ruby method, because
# UpgradeAssistant#alphabetical_sorter builds a Gtk::PropertyExpression
# against it, and that introspects the type's registered properties rather
# than calling the Ruby method directly.
class UpgradeResult < GLib::Object
  type_register

  install_property(
    GLib::Param::String.new(
      'name',
      'Name',
      'Name',
      nil,
      GLib::Param::READABLE,
    ),
  )

  attr_accessor :web_data, :local_data

  def name
    if local_data
      local_data.name
    elsif web_data
      web_data.extension
    end
  end

  # Whether the local copy will survive the upgrade: the website must publish
  # a release supporting the target shell version.
  def supported?(shell_version)
    if web_data.nil?
      false
    else
      web_data.supports_shell_version?(shell_version)
    end
  end
end
