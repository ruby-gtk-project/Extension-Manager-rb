# frozen_string_literal: true

require 'adwaita'
require_relative 'types'

# One installed extension, as GNOME Shell describes it over D-Bus.
#
# Ported from upstream's src/local/exm-extension.c. It is a GObject with the
# same seventeen properties, because the installed page sorts and filters the
# list with Gtk expressions and the row binds its switch to `enabled` and
# `state` — both of which need real GObject properties and their notify
# signals, not plain Ruby attributes.
#
# The two collection properties (session modes, donations) are plain Ruby
# attributes: upstream declares them as a boxed GPtrArray and an opaque
# pointer, neither of which the Ruby bindings can carry through a GValue, and
# nothing binds to them.
class Extension < GLib::Object
  type_register

  attr_accessor :uuid,
    :name,
    :description,
    :enabled,
    :path,
    :url,
    :version,
    :version_name,
    :error,
    :has_prefs,
    :has_update,
    :can_change,
    :is_user
  attr_reader :state
  attr_accessor :session_modes, :donations
  attr_reader :sort_rank

  def self.string_property(name)
    install_property(
      GLib::Param::String.new(
        name,
        name,
        name,
        nil,
        GLib::Param::READWRITE,
      ),
    )
  end

  def self.boolean_property(name)
    install_property(
      GLib::Param::Boolean.new(
        name,
        name,
        name,
        false,
        GLib::Param::READWRITE,
      ),
    )
  end

  # Upstream declares `state` as an enum property; the Ruby bindings have no
  # registered GType for the enumeration, so the same values travel as an int
  # over the range the enumeration uses.
  def self.state_property
    install_property(
      GLib::Param::Int.new(
        'state',
        'state',
        'state',
        0,
        Types::ExtensionState::UNINSTALLED,
        Types::ExtensionState::INITIALIZED,
        GLib::Param::READWRITE,
      ),
    )
  end

  # Not an upstream property. Upstream sorts the enabled extensions first with
  # a GtkCustomSorter over `state`; the Ruby bindings hand a custom sorter's
  # compare function raw pointers rather than objects, so the installed page
  # has to use a GtkNumericSorter instead, and that needs a numeric property
  # holding the one bit upstream's comparison looks at: 0 while the extension
  # is running, 1 otherwise.
  def self.sort_rank_property
    install_property(
      GLib::Param::Int.new(
        'sort-rank',
        'sort-rank',
        'sort-rank',
        0,
        1,
        1,
        GLib::Param::READWRITE,
      ),
    )
  end

  string_property('uuid')
  string_property('name')
  string_property('description')
  state_property
  boolean_property('enabled')
  string_property('path')
  string_property('url')
  string_property('version')
  string_property('version-name')
  string_property('error')
  boolean_property('has-prefs')
  boolean_property('has-update')
  boolean_property('can-change')
  boolean_property('is-user')
  sort_rank_property

  # Upstream's exm_extension_new takes the uuid, which is construct-only: an
  # extension's identity never changes, only the properties around it.
  def initialize(uuid)
    super()
    @uuid = uuid
    @state = Types::ExtensionState::INITIALIZED
    @enabled = false
    @has_prefs = false
    @has_update = false
    @can_change = true
    @is_user = false
    @sort_rank = 1
    @session_modes = []
    @donations = {}
  end

  # Keeping the sort rank in step with the state is what lets the numeric
  # sorter stand in for upstream's custom one.
  def state=(value)
    @state = value
    if active?
      @sort_rank = 0
    else
      @sort_rank = 1
    end
    @state
  end

  def sort_rank=(value)
    @sort_rank = value
  end

  # Upstream's compare_extension and is_extension_equal, which the list store
  # uses to keep itself sorted and to find a row again after an update.
  def <=>(other) = uuid.to_s <=> other.uuid.to_s
  def ==(other) = other.is_a?(Extension) && (self <=> other).zero?
  alias eql? ==
  def hash = uuid.to_s.hash

  def active? = state == Types::ExtensionState::ACTIVE
  def error? = state == Types::ExtensionState::ERROR
  def out_of_date? = state == Types::ExtensionState::OUT_OF_DATE
  def uninstalled? = state == Types::ExtensionState::UNINSTALLED
end
