/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2017    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

TEST(function() {

    O.enforcePluginPrivilege(test_plugin, "pTestPriv1", "action name");

    TEST.assert_exceptions(function() {
        O.enforcePluginPrivilege(test_plugin, "pRandom", "stuff");
    }, "Cannot stuff without the pRandom privilege. Add it to privilegesRequired in plugin.json");

});
