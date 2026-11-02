# frozen_string_literal: true

# Enumerations shared by the whole app.
#
# Ported from upstream's src/exm-types.h, which declares the same four
# enumerations and is run through meson's mkenums so the values are usable
# from GObject properties and blueprint closures.
#
# Upstream's comment about the file belonging in `local/` carries over: the
# extension type and state enumerations describe the GNOME Shell D-Bus API and
# belong with the manager, but keeping every enumeration in one place is what
# lets the blueprint-equivalent widget code name them without a cycle.
module Types
  # Where an extension is installed: a system-wide directory or the user's own.
  module ExtensionType
    SYSTEM = 1
    PER_USER = 2
  end

  # The lifecycle states GNOME Shell reports for an extension.
  module ExtensionState
    ACTIVE = 1
    INACTIVE = 2
    ERROR = 3
    OUT_OF_DATE = 4
    DOWNLOADING = 5
    INITIALIZED = 6
    DEACTIVATING = 7
    ACTIVATING = 8
    UNINSTALLED = 99
  end

  # The faces the install button wears.
  module InstallButtonState
    DEFAULT = 0
    INSTALLING = 1
    INSTALLED = 2
    UNSUPPORTED = 3
    LOADING = 4
  end

  # The orderings extensions.gnome.org accepts, as declared in upstream's
  # src/web/exm-search-provider.h.
  module SearchSort
    NONE = 0
    POPULARITY_DES = 1
    DOWNLOADS_DES = 2
    UPDATED_DES = 3
    CREATED_DES = 4
    POPULARITY_ASC = 5
    DOWNLOADS_ASC = 6
    UPDATED_ASC = 7
    CREATED_ASC = 8

    # The `ordering=` value for each sort, as upstream's get_sort_string maps
    # them. NONE sorts by nothing, which the search provider turns into
    # `-popularity` when there is no query to rank by relevance.
    ORDERINGS = {
      NONE           => '',
      POPULARITY_DES => '-popularity',
      DOWNLOADS_DES  => '-downloads',
      UPDATED_DES    => '-updated',
      CREATED_DES    => '-created',
      POPULARITY_ASC => 'popularity',
      DOWNLOADS_ASC  => 'downloads',
      UPDATED_ASC    => 'updated',
      CREATED_ASC    => 'created',
    }.freeze

    def self.ordering(sort) = ORDERINGS.fetch(sort, '')
  end
end
