# frozen_string_literal: true

# Haplo Platform                                    https://haplo.org
# (c) Haplo Services Ltd 2006 - 2020            https://www.haplo.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.



module ExportObjectsHelper

  EXPORT_OUTPUTS = {
    'email' => ['Contact email addresses', [KConstants::A_TITLE, KConstants::AA_NAME, KConstants::A_WORKS_FOR, KConstants::A_EMAIL_ADDRESS]],
    'mailshot' => ['Postal addresses', [KConstants::A_TITLE, KConstants::AA_NAME, KConstants::A_WORKS_FOR, KConstants::A_ADDRESS]]
  }

  # Yields if it requires the objects. Return an Enumberable containing KObjects.
  def export_objects_implementation
    permission_denied unless @request_user.policy.can_export_data?
    if request.post?
      objects = yield

      output_form = EXPORT_OUTPUTS[params['output_form']]
      attrs = (output_form == nil) ? nil : output_form[1]
      include_urls = (params['urls'] == '1')
      exporter = KTableExporter.new(attrs, include_urls)

      output_format = params['output_format']
      exported = exporter.export(objects, output_format)
      # output_format now known to be valid
      response.headers["Content-Disposition"] = "attachment; filename=export.#{output_format}"
      render :text => exported, :kind => output_format.to_sym
    end
  end

end

