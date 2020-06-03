# frozen_string_literal: true

# Haplo Platform                                    https://haplo.org
# (c) Haplo Services Ltd 2006 - 2020            https://www.haplo.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.



class UserGroups

  def initialize(user_id, kind)
    @user_id = user_id
    @kind = kind
  end

  def calculated_group_info
    @calculated_group_info ||= begin
      info = []
      KApp.with_pg_database do |db|
        # Recursively search groups, keeping track of distance
        distance = PermissionRule::RuleList::DISTANCE_FIRST_GROUP
        # Start searching with the ID of the user, next step uses the groups so far
        in_values = @user_id.to_i
        while true
          found_more = false
          # ORDER BY important for UserData system
          db.exec("SELECT member_of FROM #{KApp.db_schema_name}.user_memberships WHERE user_id IN (#{in_values}) AND is_active ORDER BY member_of").each do |row|
            i = row[0].to_i
            unless info.find { |e| e.first == i }
              info << [i, distance]
              found_more = true
            end
          end
          # Next time round?
          break unless found_more
          distance += 1
          in_values = info.map { |e| e.first }.join(',')
        end
        # Everyone other than USER_ANONYMOUS implicitly belongs in Everyone
        if @kind == User::KIND_USER && @user_id != User::USER_ANONYMOUS
          info << [User::GROUP_EVERYONE, distance]
        end
        info
      end
    end
  end

  def groups_ids
    # Just return the group IDs
    self.calculated_group_info.map { |e| e.first }
  end

  def calculate_policy_bitmask
    principals = self.groups_ids + [@user_id]
    KApp.with_pg_database do |db|
      r = db.exec("SELECT COALESCE(bit_or(perms_allow) & (~ bit_or(perms_deny)), 0) FROM #{KApp.db_schema_name}.policies WHERE user_id IN (#{principals.join(',')})")
      policy_bitmask = r.first.first.to_i
    end
  end

end
