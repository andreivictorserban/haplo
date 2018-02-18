# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


class Setup_KeychainController < ApplicationController
  policies_required :setup_system
  include SystemManagementHelper

  NOT_CHANGED = '********'.freeze

  def render_layout
    'management'
  end

  def handle_index
    @keychain = KeychainCredential.find(:all, :order => :id)
  end

  def handle_info
    @credential = KeychainCredential.find(params[:id].to_i)
    @ui = get_ui(@credential)
  end

  _GetAndPost
  def handle_edit
    # Load existing credential, or choose model for new credential
    unless params.has_key?(:id)
      unless params.has_key?(:kind)
        render :action => 'choose'
        return
      else
        model = KeychainCredential::MODELS.find do |m|
          (m[:kind] == params[:kind]) && (m[:instance_kind] == params[:instance_kind])
        end
        raise "Can't find model" unless model
        @credential = KeychainCredential.new(model)
      end
    else
      @credential = KeychainCredential.find(params[:id].to_i)
    end
    @ui = get_ui(@credential)
    # Update/create credential
    if request.post?
      @credential.name = (params[:name] || '').strip
      @credential.name = 'Unnamed credential' unless @credential.name =~ /\S/
      @credential.account = params[:account] || {}
      # Secrets aren't sent to the browser, so need to be checked against a sentinal value
      old_secrets = @credential.secret || {}
      new_secrets = {}
      # Use password so parameters are filtered out of the logs
      (params[:password] || {}).each do |key,value|
        if value == NOT_CHANGED
          if old_secrets.has_key?(key)
            new_secrets[key] = old_secrets[key]
          else
            new_secrets[key] = ''
          end
        else
          new_secrets[key] = value
        end
      end
      @credential.secret= new_secrets
      ActiveRecord::Base.logger.silence do
        # Don't log save, as it would put secrets in the logs
        @credential.save!
      end
      KApp.logger.info("KeychainCredential saved")
      redirect_to "/do/setup/keychain/info/#{@credential.id}?update=1"
    end
  end

  _GetAndPost
  def handle_delete
    @credential = KeychainCredential.find(params[:id].to_i)
    if request.post?
      if params[:delete] != 'confirm'
        @should_confirm = true
      else
        @credential.destroy
        render :action => 'refresh_list'
      end
    end
  end

  def handle_about
  end

  # -------------------------------------------------------------------------

  def get_ui(credential)
    KeychainCredential::USER_INTERFACE[[credential.kind,credential.instance_kind]] || {}
  end

end
