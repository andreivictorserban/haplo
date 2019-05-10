# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


class AccountController < ApplicationController
  policies_required :not_anonymous

  def handle_info
    @user = User.find(@request_user.id)
    @user_groups = @user.groups
    @admins = User.find(User::GROUP_ADMINISTRATORS).members
  end

end
