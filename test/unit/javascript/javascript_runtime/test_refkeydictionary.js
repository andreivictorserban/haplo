/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

TEST(function() {

    var iteratortester = function(dict, expected) {
        var vs = [];
        dict.each(function(key, value) {
            vs.push(key.toString()+'-'+value);
        });
        TEST.assert(_.isEqual(vs.sort(), _.map(expected, function(v) {
            return v[0].toString()+'-'+v[1];
        }).sort()));
    };

    // Simple dictionary
    var dict1 = O.refdict();
    TEST.assert_exceptions(function() { dict1.set("pants", 3); });
    TEST.assert_exceptions(function() { dict1.set(23, 3); });
    TEST.assert_equal(0, dict1.length);
    TEST.assert_equal(undefined, dict1.get(O.ref(5)));
    TEST.assert_equal("ping", dict1.set(O.ref(5), "ping"));   // check return from set()
    TEST.assert_equal("ping", dict1.get(O.ref(5)));
    TEST.assert_equal(1, dict1.length);
    dict1.set(O.ref(18), "carrots");
    TEST.assert_equal(2, dict1.length);
    TEST.assert_equal("ping", dict1.get(O.ref(5)));
    TEST.assert_equal("carrots", dict1.get(O.ref(18)));
    TEST.assert_equal(undefined, dict1.get(O.ref(19)));
    iteratortester(dict1, [[O.ref(5),"ping"],[O.ref(18),"carrots"]]);
    TEST.assert_equal("carrots", dict1.remove(O.ref(18))); // check return value
    TEST.assert_equal(undefined, dict1.remove(O.ref(18))); // check return value
    TEST.assert_equal(undefined, dict1.remove(O.ref(18)));
    TEST.assert_equal("ping", dict1.get(O.ref(5)));
    TEST.assert_equal(1, dict1.length);
    TEST.assert_equal(undefined, dict1.get(O.ref(18)));
    TEST.assert_equal(undefined, dict1.get(O.ref(19)));
    iteratortester(dict1, [[O.ref(5),"ping"]]);

    // Dictionary with constructor function
    var dict2ConstructCount = 0;
    var dict2 = O.refdict(function(ref) { dict2ConstructCount++; return ""+ref.objId+"/"+dict2ConstructCount; });
    TEST.assert_equal(0, dict2.length);
    TEST.assert_equal("3/1", dict2.get(O.ref(3)));
    TEST.assert_equal(1, dict2.length);
    TEST.assert_equal("29/2", dict2.get(O.ref(29)));
    TEST.assert_equal(2, dict2.length);
    TEST.assert_equal("29/2", dict2.get(O.ref(29).toString()));
    TEST.assert_equal(2, dict2.length);
    iteratortester(dict2, [[O.ref(3),"3/1"],[O.ref(29),"29/2"]]);
    dict2.set(O.ref(2), "ping");
    TEST.assert_equal(3, dict2.length);
    TEST.assert_equal("ping", dict2.get(O.ref(2)));
    dict2.remove(O.ref(29).toString());
    TEST.assert_equal("3/1", dict2.get(O.ref(3)));
    TEST.assert_equal("29/3", dict2.get(O.ref(29)));
    TEST.assert_equal("ping", dict2.get(O.ref(2)));
    iteratortester(dict2, [[O.ref(3),"3/1"],[O.ref(29),"29/3"],[O.ref(2),"ping"]]);

    // Check that iterators stop
    var dict3 = O.refdict(null, 100000000000);   // construct with massive size hint
    dict3.set(O.ref(34), "pong");
    dict3.set(O.ref(45), "ping");
    var callcount = 0;
    dict3.each(function(key,value) {
        callcount++;
        return true;
    });
    TEST.assert_equal(2, dict3.length);
    TEST.assert_equal(1, callcount);

    // --------------------------------------------------------------------------------------------------------------------------

    // Hierarchical variant
    var hdict1 = O.refdictHierarchical();
    hdict1.set(TYPE["std:type:equipment"], "equipment");
    TEST.assert_equal("equipment", hdict1.get(TYPE["std:type:equipment"]));
    TEST.assert_equal("equipment", hdict1.get(TYPE["std:type:equipment:computer"]));
    TEST.assert_equal("equipment", hdict1.get(TYPE["std:type:equipment:laptop"]));
    TEST.assert_equal("equipment", hdict1.get(TYPE["std:type:equipment:computer"])); // repeat, will come from 'cache'
    TEST.assert_equal("equipment", hdict1.get(TYPE["std:type:equipment:laptop"])); // repeat
    TEST.assert_equal(undefined, hdict1.get(TYPE["std:type:event:conference"]));
    TEST.assert_equal(undefined, hdict1.get(TYPE["std:type:event:conference"])); // repeat
    iteratortester(hdict1, [[TYPE["std:type:equipment"],"equipment"]]);

    TEST.assert(_.isEqual(["equipment"], hdict1.getAllInHierarchy(TYPE["std:type:equipment"])));
    var firstComputerLookup = hdict1.getAllInHierarchy(TYPE["std:type:equipment:computer"]);
    TEST.assert(_.isEqual(["equipment"], firstComputerLookup));
    TEST.assert(_.isEqual(["equipment"], hdict1.getAllInHierarchy(TYPE["std:type:equipment:laptop"])));
    TEST.assert(firstComputerLookup === hdict1.getAllInHierarchy(TYPE["std:type:equipment:computer"]));
    TEST.assert(_.isEqual(["equipment"], hdict1.getAllInHierarchy(TYPE["std:type:equipment:computer"]))); // repeat, will come from 'cache'
    TEST.assert(_.isEqual(["equipment"], hdict1.getAllInHierarchy(TYPE["std:type:equipment:laptop"]))); // repeat
    TEST.assert(_.isEqual([], hdict1.getAllInHierarchy(TYPE["std:type:event:conference"])));

    hdict1.set(TYPE["std:type:equipment:computer"], "computer");
    TEST.assert_equal("equipment", hdict1.get(TYPE["std:type:equipment"]));
    TEST.assert_equal("computer", hdict1.get(TYPE["std:type:equipment:computer"]));
    TEST.assert_equal("computer", hdict1.get(TYPE["std:type:equipment:laptop"]));
    TEST.assert_equal(undefined, hdict1.get(TYPE["std:type:event:conference"]));
    iteratortester(hdict1, [[TYPE["std:type:equipment"],"equipment"],[TYPE["std:type:equipment:computer"],"computer"]]);

    TEST.assert(firstComputerLookup !== hdict1.getAllInHierarchy(TYPE["std:type:equipment:computer"]));
    TEST.assert(_.isEqual(["equipment","computer"], hdict1.getAllInHierarchy(TYPE["std:type:equipment:laptop"])));

    // Hierarchical with constructor function
    var hdict2ConstructCount = 0;
    var hdict2 = O.refdictHierarchical(function(ref) { hdict2ConstructCount++; return ""+ref+"/"+hdict2ConstructCount; });
    // Constructor function interacts in an interesting way, which isn't entirely useful, but keep the functionality
    TEST.assert(_.isEqual([], hdict2.getAllInHierarchy(TYPE["std:type:equipment"])));
    TEST.assert_equal(""+TYPE["std:type:equipment"]+"/1", hdict2.get(TYPE["std:type:equipment"]));
    TEST.assert(_.isEqual([""+TYPE["std:type:equipment"]+"/1"], hdict2.getAllInHierarchy(TYPE["std:type:equipment"])));
    TEST.assert_equal(""+TYPE["std:type:equipment"]+"/1", hdict2.get(TYPE["std:type:equipment:computer"]));
    TEST.assert_equal(""+TYPE["std:type:equipment"]+"/1", hdict2.get(TYPE["std:type:equipment:laptop"]));
    TEST.assert_equal(""+TYPE["std:type:event:conference"]+"/2", hdict2.get(TYPE["std:type:event:conference"]));
    TEST.assert_equal(""+TYPE["std:type:event:conference"]+"/2", hdict2.get(TYPE["std:type:event:conference"]));
    hdict2.set(TYPE["std:type:equipment:computer"], "computer");
    TEST.assert_equal(""+TYPE["std:type:equipment"]+"/1", hdict2.get(TYPE["std:type:equipment"]));
    TEST.assert_equal("computer", hdict2.get(TYPE["std:type:equipment:computer"]));
    TEST.assert_equal("computer", hdict2.get(TYPE["std:type:equipment:laptop"]));
    TEST.assert_equal(""+TYPE["std:type:event:conference"]+"/2", hdict2.get(TYPE["std:type:event:conference"]));
    TEST.assert_equal(""+TYPE["std:type:intranet-page"]+"/3", hdict2.get(TYPE["std:type:intranet-page"]));
    TEST.assert_equal(""+TYPE["std:type:intranet-page"]+"/3", hdict2.get(TYPE["std:type:intranet-page"]));
    iteratortester(hdict2, [[TYPE["std:type:equipment"],""+TYPE["std:type:equipment"]+"/1"], [TYPE["std:type:equipment:computer"],"computer"], [TYPE["std:type:event:conference"],""+TYPE["std:type:event:conference"]+"/2"], [TYPE["std:type:intranet-page"],""+TYPE["std:type:intranet-page"]+"/3"]]);

    // Hierarchical with constructor function and use of getWithoutHierarchy()
    var hdict3ConstructCount = 0;
    var hdict3 = O.refdictHierarchical(function(ref) { hdict3ConstructCount++; return hdict3ConstructCount; });
    TEST.assert_equal(1, hdict3.get(TYPE["std:type:equipment"]));
    TEST.assert_equal(1, hdict3.get(TYPE["std:type:equipment:laptop"]));
    TEST.assert_equal(2, hdict3.getWithoutHierarchy(TYPE["std:type:equipment:computer"]));
    TEST.assert_equal(2, hdict3.get(TYPE["std:type:equipment:laptop"]));
    TEST.assert_equal(2, hdict3.get(TYPE["std:type:equipment:computer"]));
    TEST.assert_equal(1, hdict3.get(TYPE["std:type:equipment"]));

});
