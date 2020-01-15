/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package org.haplo.convert;

import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.OutputStreamWriter;

import net.htmlparser.jericho.Source;
import net.htmlparser.jericho.Renderer;

import org.haplo.op.Operation;

public class HTMLToText extends Operation {
    private String inputPathname;
    private String outputPathname;

    /**
     * Constructor.
     *
     * @param inputPathname Pathname of input file.
     * @param outputPathname Pathname to save the file.
     */
    public HTMLToText(String inputPathname, String outputPathname) {
        this.inputPathname = inputPathname;
        this.outputPathname = outputPathname;
    }

    protected void performOperation() {
        File output = new File(outputPathname);

        try(FileInputStream html = new FileInputStream(new File(inputPathname))) {

            Source source = new Source(html);
            source.fullSequentialParse();
            Renderer renderer = new Renderer(source);
            renderer.setIncludeHyperlinkURLs(false);    // URLs look nasty in the output
            try(
                FileOutputStream fileStream = new FileOutputStream(output);
                OutputStreamWriter writer = new OutputStreamWriter(fileStream, "UTF-8")
            ) {
                renderer.writeTo(writer);
            }
        } catch(Exception e) {
            // Delete the output but otherwise ignore the error
            output.delete();
            logIgnoredException("HTMLToText failed", e);
        }
    }
}
