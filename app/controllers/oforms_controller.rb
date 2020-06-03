# frozen_string_literal: true

# Haplo Platform                                    https://haplo.org
# (c) Haplo Services Ltd 2006 - 2020            https://www.haplo.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.



# TODO: Document that oForms bundles are not protected and published to anyone who can read URLs.
# TODO: Or make oForms bundles respect the "allow anonymous access" setting in plugin.json?

# Provides support for oForms within in JavaScript plugins

class OFormsController < ApplicationController
  policies_required nil

  NUMBER_OF_MATCHES_IN_DATA_SOURCE_LOOKUP = 10

  # Make the bundle available to the client side
  def handle_bundle_api
    javascript = nil
    # Decode the URL path to find the plugin's path component and the form's ID
    raise "Bad oForms bundle request" unless request.path =~ /\/\~\d+\/(\w+)\/([a-zA-Z_]+?)\/([a-zA-Z0-9_-]+)\/\d+\z/
    path_component = $1
    locale_id = $2
    form_id = $3
    # If there's a plugin which uses this path component, call the private hook to get the
    # response JavaScript from the plugin.
    plugin = KPlugin.get_by_path_component(path_component)
    if plugin
      call_hook(:hPlatformInternalOFormsBundle) do |hooks|
        h = hooks.run(plugin.name, form_id, locale_id)
        javascript = h.bundle
      end
    end
    if javascript == nil
      # Form wasn't found
      render :text => "Bundle not known", :status => 404, :kind => :text
    else
      # Set response validity time to 4 hours to avoid too many requests
      set_response_validity_time(14400)
      render :text => javascript, :kind => :javascript
    end
  end

  # Implement the server side of the object lookup data source
  def handle_src_objects_api
    # Make a search with truncated words everywhere
    given_text = (params['q'] || '').strip.downcase
    text = given_text.split(/\s+/).map { |e| e + '*' } .join(' ')
    # Decode types argument
    types = (params['t'] || '').strip.split(',').map { |t| KObjRef.from_presentation(t) } .compact
    if types.empty?
      return data_source_message_response("Bad configuration")
    end
    query = KObjectStore.query_and.free_text(text, A_TITLE)
    if types.length == 1
      query.link(types.first, A_TYPE)
    else
      subquery = query.or
      types.each { |type| subquery.link(type, A_TYPE) }
    end
    # Add constraints and execute
    query.add_exclude_labels([O_LABEL_STRUCTURE])
    query.maximum_results(NUMBER_OF_MATCHES_IN_DATA_SOURCE_LOOKUP)
    results = query.execute(:all, :title)
    if results.length > 0
      found_items = []
      json_response = {:results => found_items}
      results.each do |obj|
        # Must use the title exactly (not descriptive) so that searches definately match
        title_text = maybe_append_object_to_autocomplete_list(found_items, obj, :simple)
        # Check for an exact match to automatically select it on the client
        if title_text &&
              !(json_response.has_key?(:selectId)) &&
              given_text == title_text.downcase
          json_response[:selectId] = obj.objref.to_presentation
          json_response[:selectDisplay] = title_text
        end
      end
      render :text => json_response.to_json, :kind => :json
    else
      data_source_message_response("Nothing found")
    end
  end

private

  def data_source_message_response(msg)
    render :text => {:message => msg}.to_json, :kind => :json
    nil
  end

end
