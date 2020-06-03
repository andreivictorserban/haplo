/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package org.haplo.jsinterface.app;

public interface AppAuditEntry {
    public int id();

    public Long created_at_milliseconds();

    public String remote_addr();

    public Integer user_id();

    public Integer auth_user_id();

    public Integer api_key_id();

    public String kind();

    public AppLabelList labels();

    public Integer objref_obj_id();

    public Integer entity_id();

    public boolean displayable();

    public String data_json();
}
