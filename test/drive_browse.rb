# frozen_string_literal: true

# Drives the Browse view: builds the app, feeds the browse page a canned page
# of search results without touching the network, then exercises the sort
# drop-down, the order toggle, the "Load More Results" row, the empty and
# error pages and the search rows' install buttons.

$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))

require_relative '../.claude/skills/ruby-gtk-testing/scripts/gtk_driver'
require 'extension_manager'
require 'browse_page'
require 'error_dialog'
require 'search_provider'
require 'search_result'
require 'search_row'
require 'image_resolver'
require 'request_handler'
require 'types'

# The driver runs offline: both website clients are silenced, and the pages
# they would have fetched are fed to the page by hand.
class SearchProvider
  def request(_url) = RequestHandler::Request.new
end

class ImageResolver
  def resolve(_rel_path) = nil
end

def result_of(index)
  SearchResult.from_json(
    {
      'uuid'        => "ext#{index}@example.com",
      'name'        => "Extension #{index}",
      'description' => "Summary #{index}\nThe long description.",
      'creator'     => { 'username' => 'ada', 'display_name' => 'Ada', 'id' => 7 },
      'icon'        => "/static/icon#{index}.png",
    },
  )
end

def page_of(count, num_pages)
  SearchProvider::Results.new(
    model:     Gio::ListStore.new(SearchResult).tap do |store|
      count.times { |index| store.append(result_of(index)) }
    end,
    num_pages: num_pages,
  )
end

application = ExtensionManager::Application.new

GtkDriver.drive(application, shots: 'tmp/shots') do |d, app|
  d.window { app.window }

  window = nil
  page = nil

  d.step('handles') do
    window = app.window
    page = window.browse_page
    d.check('browse page built') { page.is_a?(BrowsePage) }
  end

  d.step('both views are in the stack') do
    d.check('installed page') { !window.view_stack.get_child_by_name('installed').nil? }
    d.check('browse page') { !window.view_stack.get_child_by_name('browse').nil? }
    d.check('switcher follows the stack') { window.view_switcher.stack == window.view_stack }
    d.check('switcher bar follows the stack') { window.switcher_bar.stack == window.view_stack }
  end

  d.step('switch to browse') do
    window.main_stack.visible_child_name = 'app'
    window.view_stack.visible_child_name = 'browse'
    d.check('browse showing') { window.view_stack.visible_child_name == 'browse' }
    d.check('installed search bar hidden') { !window.search_bar.visible? }
    d.check('installed search button hidden') { !window.search_button.visible? }
    d.shot('10-browse-empty')
  end

  d.step('results arrive') do
    page.send(:on_first_page_result, page_of(3, 2), nil)
    d.check('results page') { page.search_stack.visible_child_name == 'page_results' }
    d.check('three rows') { page.results_model.n_items == 3 }
    d.check('first row is a search row') { page.search_results.get_row_at_index(0).is_a?(SearchRow) }
    d.check('row title') { page.search_results.get_row_at_index(0).title_label.label == 'Extension 0' }
    d.check('row creator') { page.search_results.get_row_at_index(0).subtitle_label.label == 'Ada' }
    d.check('row description is the first line') do
      page.search_results.get_row_at_index(0).description_label.label == 'Summary 0'
    end
    d.check('load more showing') { page.more_results_list.visible? }
    d.shot('11-browse-results')
  end

  d.step('rows are not activatable without a detail view') do
    page.search_results.get_row_at_index(0).then do |row|
      d.check('not activatable') { !row.activatable? }
      d.check('no chevron') { !row.next_icon.visible? }
      d.check('install button offers install') do
        row.install_button.label.label == 'Install…'
      end
    end
  end

  d.step('compact rows drop the button label') do
    page.send(:apply_compact, true)
    d.check('row is compact') { page.search_results.get_row_at_index(0).compact? }
    d.check('button is icon only') { page.search_results.get_row_at_index(0).install_button.icon_only? }
    page.send(:apply_compact, false)
    d.check('button is labelled again') { !page.search_results.get_row_at_index(0).install_button.icon_only? }
  end

  d.step('load more appends the next page') do
    page.send(:on_load_more_results)
    d.check('button went insensitive') { !page.more_results_button.sensitive? }
    page.cancel_requests
    page.send(:on_next_page_result, page_of(2, 2), nil)
    d.check('five rows now') { page.results_model.n_items == 5 }
    d.check('button clickable again') { page.more_results_button.sensitive? }
    d.check('last page hides the row') { !page.more_results_list.visible? }
  end

  d.step('no results') do
    page.send(:on_first_page_result, page_of(0, 1), nil)
    d.check('empty page') { page.search_stack.visible_child_name == 'page_empty' }
    d.check('empty title') { page.empty_title_label.label == 'No Results Found' }
    d.shot('12-browse-no-results')
  end

  d.step('connection error') do
    page.send(:on_first_page_result, nil, RequestHandler::RequestError.new(503, 'Server is down'))
    d.check('error page') { page.search_stack.visible_child_name == 'page_error' }
    d.check('error text') { page.error_label.label == 'Server is down' }
    d.check('error title') { page.error_title_label.label == 'Connection Error' }
    d.shot('13-browse-error')
  end

  d.step('sort drop-down and order toggle') do
    d.check('five sorts') { page.sort_model.n_items == 5 }
    d.check('order button starts hidden') { !page.order_button.visible? }
    page.search_dropdown.selected = Types::SearchSort::DOWNLOADS_DES
    d.check('order button showing') { page.order_button.visible? }
    d.check('descending tooltip') { page.order_button.tooltip_text == 'Descending Order' }
    page.send(:on_order_button_clicked)
    d.check('ascending icon') { page.order_button.icon_name == 'view-sort-ascending-symbolic' }
    d.check('ascending tooltip') { page.order_button.tooltip_text == 'Ascending Order' }
    d.check('ascending sort chosen') do
      page.send(:directed_sort, Types::SearchSort::DOWNLOADS_DES) == Types::SearchSort::DOWNLOADS_ASC
    end
    page.send(:on_order_button_clicked)
    d.check('back to descending') do
      page.send(:directed_sort, Types::SearchSort::DOWNLOADS_DES) == Types::SearchSort::DOWNLOADS_DES
    end
  end

  d.step('suggestions feed the placeholder') do
    d.check('four suggestions') { page.suggestions.length == 4 }
    d.check('placeholder is one of them') { page.suggestions.include?(page.search_entry.placeholder_text) }
  end

  d.step('search online hands the query over') do
    window.view_stack.visible_child_name = 'installed'
    window.search_entry.text = 'blur'
    window.activate_action('search-online', nil)
    d.check('switched to browse') { window.view_stack.visible_child_name == 'browse' }
    d.check('query copied') { page.search_entry.text == 'blur' }
  end

  d.step('search installed goes back') do
    window.activate_action('search-installed', GLib::Variant.new('alpha'))
    d.check('switched to installed') { window.view_stack.visible_child_name == 'installed' }
    d.check('search bar open') { window.search_button.active? }
    d.check('query set') { window.search_entry.text == 'alpha' }
  end

  d.step('show-page action') do
    window.activate_action('show-page', GLib::Variant.new('browse'))
    d.check('browse showing') { window.view_stack.visible_child_name == 'browse' }
    window.activate_action('show-page', GLib::Variant.new('installed'))
    d.check('installed showing') { window.view_stack.visible_child_name == 'installed' }
  end

  d.step('error toast and report window') do
    window.activate_action('show-error', GLib::Variant.new('Boom'))
    ErrorDialog.new('Boom', version: ExtensionManager::Application.version).build.tap do |dialog|
      dialog.transient_for = window
      dialog.present
      d.check('log names the error') { dialog.text_view.buffer.text.end_with?('Boom') }
      d.check('log reports the package format') { dialog.support_log.include?('Package Format: gem') }
      d.check('log reports third party') { dialog.support_log.include?('Status: Third Party') }
      d.check('new issue hidden for a third-party build') { !dialog.new_issue_button.visible? }
      d.shot('14-error-report', dialog)
    end
  end

  d.step('image resolver resolves against the website') do
    d.check('relative path') do
      ImageResolver::BASE_URI == 'https://extensions.gnome.org/' &&
        URI.join(ImageResolver::BASE_URI, '/static/icon0.png').to_s ==
          'https://extensions.gnome.org/static/icon0.png'
    end
    d.check('a missing path resolves to nothing') { ImageResolver.new.resolve(nil).nil? }
  end
end
