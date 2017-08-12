/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2017    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


TEST(function() {

    var X = '';

    // Create loopback 0
    var Bus0 = O.messageBus.loopback("test:loopback:0");

    // Same bus object returned if requested again
    TEST.assert(Bus0 === O.messageBus.loopback("test:loopback:0"));

    Bus0.message().body({m:0}).send();
    TEST.assert_equal(X, '');

    // Receive message on loopback 0
    Bus0.receive(function(msg) {
        TEST.assert_equal(0, O.currentUser.id); // must be SYSTEM
        X += 'A:'+msg.parsedBody().m+',';
    });

    Bus0.message().body({m:1}).send();
    TEST.assert_equal(X, 'A:1,')

    // Create loopback 1
    var Bus1 = O.messageBus.loopback("test:loopback:1").
        receive(function(msg) {
            TEST.assert_equal(0, O.currentUser.id); // must be SYSTEM
            X += 'B:'+msg.parsedBody().m+',';
        });
    TEST.assert_equal(Bus1, O.messageBus.loopback("test:loopback:1"));

    // Receive message on loopback 0 again, doesn't get delivered to 1
    Bus0.message().body({m:2}).send();
    TEST.assert_equal(X, 'A:1,A:2,')

    // Receive message on loopback 1
    Bus1.message().body({m:3}).send();
    TEST.assert_equal(X, 'A:1,A:2,B:3,')

    // Multiple receivers on loopback 0
    Bus0.receive(function(msg) {
        X += 'C:'+msg.parsedBody().m+',';
    });
    Bus0.message().body({m:4}).send();
    TEST.assert_equal(X, 'A:1,A:2,B:3,A:4,C:4,')

    // Loopback messages received as SYSTEM for consistency with other message bus types
    O.impersonating(O.user(41), function() {
        Bus0.message().body({m:6}).send();
        Bus1.message().body({m:7}).send();
    });

    // Bad API use
    TEST.assert_exceptions(function() { Bus0.message().body(); },               "Message body is not a JSON-compatible Object");
    TEST.assert_exceptions(function() { Bus0.message().body(undefined); },      "Message body is not a JSON-compatible Object");
    TEST.assert_exceptions(function() { Bus0.message().body(1); },              "Message body is not a JSON-compatible Object");
    TEST.assert_exceptions(function() { Bus0.message().body(function() {}); },  "Message body is not a JSON-compatible Object");
    TEST.assert_exceptions(function() { Bus0.message().body({}).body({}); },    "Message body is already set");
    TEST.assert_exceptions(function() { Bus0.message().send(); },               "Cannot send a message without a message body");
    // Can't modify messages after receiving them
    var capturedMessage;
    Bus0.receive(function(msg) { capturedMessage = msg; });
    Bus0.message().body({}).send();
    TEST.assert_exceptions(function() { capturedMessage.body({}); }, "Message cannot be modified");
    Bus0.message().body({}).send();
    TEST.assert_exceptions(function() { capturedMessage.send(); },   "Message cannot be modified");

    // Delivery reports
    Bus0.receive(function(msg) { if(msg.parsedBody().throwException) { throw new Error("error on delivery"); } });
    var deliveryStatus, deliveryInfomation, deliveryMessage;
    Bus0.deliveryReport(function(status, information, message) {
        deliveryStatus = status; deliveryInfomation = information; deliveryMessage = message;
    });
    // Successful delivery on loopback (has own implementation)
    Bus0.message().body({delivery1:true}).send();
    TEST.assert_equal("success", deliveryStatus);
    TEST.assert(_.isEqual({}, deliveryInfomation));
    TEST.assert(deliveryMessage.parsedBody().delivery1);
    // Failed deilvery on loopback
    Bus0.message().body({delivery2:true,throwException:true}).send();
    TEST.assert_equal("failure", deliveryStatus);
    TEST.assert("exception" in deliveryInfomation);
    TEST.assert(deliveryMessage.parsedBody().delivery2);

});
