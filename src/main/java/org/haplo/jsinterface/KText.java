/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package org.haplo.jsinterface;

import org.haplo.javascript.Runtime;
import org.haplo.javascript.OAPIException;
import org.mozilla.javascript.*;

import org.haplo.jsinterface.app.*;

public class KText extends KScriptable {
    private AppText text;
    private String string;
    private String html;
    private boolean isMutableIdentifier;

    public KText() {
        this.isMutableIdentifier = false;
    }

    public void setText(AppText text) {
        this.text = text;
    }

    // --------------------------------------------------------------------------------------------------------------
    public void jsConstructor() {
    }

    public String getClassName() {
        return "$KText";
    }

    @Override
    protected String getConsoleData() {
        return "'" + jsFunction_toString(null) + "'";
    }

    public static Scriptable jsStaticFunction_constructKText(int typecode, String text, boolean isJSON) {
        return KText.fromAppText(rubyInterface.constructKText(typecode, text, isJSON));
    }

    // --------------------------------------------------------------------------------------------------------------
    static public KText fromAppText(AppText appObj) {
        KText text = (KText)Runtime.getCurrentRuntime().createHostObject("$KText");
        text.setText(appObj);
        return text;
    }

    // --------------------------------------------------------------------------------------------------------------
    public AppText toRubyObject() {
        return text;
    }

    // --------------------------------------------------------------------------------------------------------------
    public boolean jsGet_isIdentifier() {
        throw new OAPIException("isIdentifier property is no longer implemented");
    }

    public void setAsMutableIdentifier() {
        this.isMutableIdentifier = true;
    }

    public String jsFunction_toString(Object format) {
        if(format != null && !(format instanceof CharSequence)) {
            format = null;
        }
        // Only cache the strings if no format is used
        if(format != null) {
            return rubyInterface.convertToString(this.text, format.toString());
        } else {
            if(this.string == null) {
                this.string = rubyInterface.convertToString(this.text, null);
            }
            return this.string;
        }
    }

    // Convenient abbreviation for toString
    public String jsFunction_s(Object format) {
        return jsFunction_toString(format);
    }

    // HTML version of the text
    public String jsFunction_toHTML() {
        if(this.html == null) {
            this.html = text.to_html();
        }
        return html;
    }

    // Split into fields, which depend on the type of text object.
    // Includes a "typecode" key, containing the typecode of the text object
    public Object jsFunction_toFields() {
        String json = rubyInterface.toFieldsJson(this.text);
        try {
            return Runtime.getCurrentRuntime().makeJsonParser().parseValue(json);
        } catch(org.mozilla.javascript.json.JsonParser.ParseException e) {
            throw new OAPIException("Couldn't JSON decode text fields data", e);
        }
    }

    // Typecode
    public int jsGet_typecode() {
        return text.k_typecode();
    }

    // Returns type of plugin defined text type, if this is one, or null
    public String jsGet__pluginDefinedTextType() {
        return rubyInterface.maybePluginDefinedTextType(this.text);
    }

    // --------------------------------------------------------------------------------------------------------------
    // Properties of file identifiers
    private AppText asFileIdentifier() {
        // Can't do something nice like if(this.text instanceof AppIdentifierFile) because of JRuby limitations
        if((this.text != null) && (this.text.k_typecode() == 27)) {
            return this.text;
        } else {
            throw new OAPIException("This Text object is not a File Identifier.");
        }
    }

    private AppText cloningFileIdentifier() {
        if(!isMutableIdentifier) {
            throw new OAPIException("This is not a mutable File Identifier.");
        }
        return (this.text = asFileIdentifier().dup());
    }

    // Getters
    public String jsGet_filename() {
        return asFileIdentifier().toString();
    }

    public String jsGet_digest() {
        return asFileIdentifier().digest();
    }

    public Long jsGet_fileSize() {
        return asFileIdentifier().size();
    }

    public String jsGet_mimeType() {
        return asFileIdentifier().mime_type();
    }

    public String jsGet_trackingId() {
        return asFileIdentifier().tracking_id();
    }

    public String jsGet_logMessage() {
        return asFileIdentifier().log_message();
    }

    public String jsGet_version() {
        return asFileIdentifier().version_string();
    }

    // Setters clone the underlying Ruby object first to prevent modifications of identifiers inside objects
    public void jsSet_mimeType(String mimeType) {
        cloningFileIdentifier().setMime_type(mimeType);
    }

    public void jsSet_trackingId(String trackingId) {
        cloningFileIdentifier().setTracking_id(trackingId);
    }

    public void jsSet_logMessage(String logMessage) {
        cloningFileIdentifier().setLog_message(logMessage);
    }

    public void jsSet_version(String version) {
        cloningFileIdentifier().setVersion_string(version);
    }

    public void jsSet_filename(String filename) {
        cloningFileIdentifier().setPresentation_filename(filename);
        this.string = this.html = null;
    }

    public KText jsFunction_mutableCopy() {
        KText clone = KText.fromAppText(asFileIdentifier().dup());
        clone.setAsMutableIdentifier();
        return clone;
    }

    // So you can call identifier() on either a File or FileIndentifier
    public KText jsFunction_identifier() {
        asFileIdentifier(); // check it's actually a file identifier
        return this;
    }

    // --------------------------------------------------------------------------------------------------------------
    // Interface to Ruby functions
    public interface Ruby {
        public AppText constructKText(int typecode, String text, boolean isJSON);

        public String convertToString(AppText text, String format);

        public String toFieldsJson(AppText text);

        public String maybePluginDefinedTextType(AppText text);
    }
    private static Ruby rubyInterface;

    public static void setRubyInterface(Ruby ri) {
        rubyInterface = ri;
    }
}
