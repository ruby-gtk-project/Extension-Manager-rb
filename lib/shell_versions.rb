# frozen_string_literal: true

# The set of GNOME Shell versions an extension release supports.
#
# Ported from upstream's src/web/model/exm-shell-versions.c, a reference
# counted boxed list of (major, minor, point) entries. Ruby needs none of the
# reference counting; what matters is exm_shell_versions_supports, whose rule
# is reproduced exactly: a version matches when the major versions are equal
# and the asked-for minor version is at least as specific as the stored one.
class ShellVersions
  Entry = Data.define(:major, :minor, :point)

  attr_reader :versions

  def initialize
    @versions = []
  end

  # The website serves the version list as an array of objects, each with a
  # major, minor and point member, which is what upstream's
  # deserialize_shell_versions reads.
  def self.from_json(shell_versions)
    new.tap do |versions|
      Array(shell_versions).each do |entry|
        versions.add(
          entry.fetch('major', -1).to_i,
          entry.fetch('minor', -1).to_i,
          entry.fetch('point', -1).to_i,
        )
      end
    end
  end

  def add(major, minor, point)
    @versions << Entry.new(major: major, minor: minor, point: point)
    self
  end

  # "3.38.1" and "45" are both valid; the parts that are absent are -1, which
  # is how upstream marks "this release does not pin that part".
  def add_version_string(version_string)
    version_string.split('.').map(&:to_i).then do |parts|
      add(parts.fetch(0, -1), parts.fetch(1, -1), parts.fetch(2, -1))
    end
  end

  # Upstream's comment is the specification: the shell version can be "3.38"
  # or "45", and a release supports it when the majors match and either side
  # leaves the minor unpinned, or the running minor is at least the pinned one.
  #
  # An empty version list means the website never declared one, which upstream
  # reads as a retired extension and refuses to call supported.
  def supports?(shell_version)
    parts = shell_version.to_s.split('.', 2)
    if versions.empty? || parts.empty?
      false
    else
      major = parts.fetch(0).to_i
      minor = -1
      if parts.length > 1
        minor = parts.fetch(1).to_i
      end
      versions.any? { |entry| entry_supports?(entry, major, minor) }
    end
  end

  def empty? = versions.empty?

  private

    def entry_supports?(entry, major, minor)
      entry.major == major && (entry.minor.negative? || minor.negative? || minor >= entry.minor)
    end
end
