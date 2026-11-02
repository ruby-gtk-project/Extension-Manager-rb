# frozen_string_literal: true

require 'adwaita'
require_relative 'shell_versions'

# One published release of an extension.
#
# Ported from upstream's src/web/model/exm-version-result.c. Its
# shell_versions member arrives as an array of {major, minor, point} objects,
# which upstream's deserialize_shell_versions folds into an ExmShellVersions;
# exm_version_result_supports_shell_version then asks that list.
class VersionResult < GLib::Object
  type_register

  attr_accessor :extension, :version, :version_name, :status, :created, :session_modes
  attr_reader :shell_versions

  def self.from_json(object)
    new.tap do |result|
      result.assign(object)
    end
  end

  def initialize
    super()
    @version = 0
    @status = 0
    @session_modes = []
    @shell_versions = ShellVersions.new
  end

  def assign(object)
    @extension = object['extension']
    @version = object.fetch('version', 0).to_i
    @version_name = object['version_name']
    @status = object.fetch('status', 0).to_i
    @created = object['created']
    @session_modes = Array(object['session_modes'])
    @shell_versions = ShellVersions.from_json(object['shell_versions'])
  end

  def supports_shell_version?(shell_version) = shell_versions.supports?(shell_version)
end
