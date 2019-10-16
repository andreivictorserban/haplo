/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package org.haplo.text.extract;

import org.apache.poi.ooxml.extractor.ExtractorFactory; // while in ooxml package, also detects old OLE2 file formats
import org.apache.poi.extractor.POITextExtractor;
import org.apache.xmlbeans.XmlException;
import org.apache.poi.openxml4j.exceptions.OpenXML4JException;

import java.io.File;
import java.io.OutputStream;
import java.io.InputStream;
import java.io.PrintStream;
import java.io.IOException;

import org.haplo.text.TextExtractOp;

public class MSOffice extends TextExtractOp {
    public MSOffice(String inputPathname) {
        super(inputPathname);
    }

    protected String extract() throws IOException {
        POITextExtractor extractor = null;
        try {
            extractor = ExtractorFactory.createExtractor(new File(getInputPathname()));
            String text = null;
            try {
                text = extractor.getText();
            } finally {
                extractor.close();
            }
            return text;
        } catch(OpenXML4JException e) {
            return "";
        } catch(XmlException e) {
            return "";
        }
    }
}
