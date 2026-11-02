# frozen_string_literal: true

require 'adwaita'

# The three confirmations the window asks for.
#
# Ported from the three Adw.AlertDialog blocks at the end of upstream's
# src/exm-window.blp: uninstalling one extension, uninstalling a selection of
# them, and installing an extension that does not support the running shell.
# The headings, bodies, responses, appearances and default and close
# responses are upstream's.
#
# Each dialog is built fresh per use rather than kept as a template child:
# upstream reuses one instance per window and sets the selection dialog's body
# before every showing, which amounts to the same thing.
module ConfirmDialogs
  REMOVE_HEADING = 'Uninstall Extension?'
  REMOVE_BODY = "The extension's features and functionality will no longer be accessible. " \
                'Are you sure you want to uninstall?'
  SELECT_REMOVE_HEADING = 'Uninstall Extensions?'
  UNSUPPORTED_HEADING = 'Unsupported Extension'
  UNSUPPORTED_BODY = 'This extension does not support your GNOME Shell version. ' \
                     'It may cause errors if installed.'

  # Asks before uninstalling one extension; yields when the answer is "yes".
  def self.remove(parent, &block)
    alert(REMOVE_HEADING, REMOVE_BODY).tap do |dialog|
      dialog.add_response('no', '_No')
      dialog.add_response('yes', '_Yes')
      dialog.set_response_appearance('yes', :destructive)
      dialog.default_response = 'no'
      dialog.close_response = 'no'
      answer(
        dialog,
        parent,
        'yes',
        &block
      )
    end
  end

  # Asks before uninstalling a selection. The body counts them, as upstream's
  # on_uninstall_selected_clicked does before showing the dialog.
  def self.remove_selected(parent, count, &block)
    alert(SELECT_REMOVE_HEADING, selection_body(count)).tap do |dialog|
      dialog.add_response('no', '_No')
      dialog.add_response('yes', '_Yes')
      dialog.set_response_appearance('yes', :destructive)
      dialog.default_response = 'no'
      dialog.close_response = 'no'
      answer(
        dialog,
        parent,
        'yes',
        &block
      )
    end
  end

  # Warns before installing an extension the running shell does not support;
  # yields when the user installs it anyway, and calls `on_decline` when the
  # user goes back instead — upstream reports that refusal as an
  # install-status of UNSUPPORTED, so the caller has to hear about it.
  def self.unsupported(parent, on_decline: nil, &block)
    alert(UNSUPPORTED_HEADING, UNSUPPORTED_BODY).tap do |dialog|
      dialog.add_response('install', '_Install Anyway')
      dialog.add_response('back', '_Go Back')
      dialog.set_response_appearance('install', :destructive)
      dialog.set_response_appearance('back', :suggested)
      dialog.default_response = 'back'
      dialog.close_response = 'back'
      dialog.prefer_wide_layout = true
      answer(
        dialog,
        parent,
        'install',
        on_other: on_decline,
        &block
      )
    end
  end

  # Translators: "%u" = number of selected extensions
  def self.selection_body(count)
    if count == 1
      "The extension's features and functionality will no longer be accessible. " \
        'Are you sure you want to uninstall 1 extension?'
    else
      'Their features and functionality will no longer be accessible. ' \
        "Are you sure you want to uninstall #{count} extensions?"
    end
  end

  def self.alert(heading, body) = Adwaita::AlertDialog.new(heading, body)

  # Adw.AlertDialog answers through its `response` signal; the block runs only
  # for the response that means "go ahead", which is what upstream checks for
  # in its adw_alert_dialog_choose_finish callbacks.
  def self.answer(dialog, parent, affirmative, on_other: nil, &block)
    dialog.signal_connect('response') do |_dialog, response|
      if response == affirmative
        block&.call
      else
        on_other&.call
      end
    end
    dialog.present(parent)
  end
end
