package jp.osmf.mfc;

//
// Utility to generate localized map_features.xml and map_features/feature.xml
//
// Copyright 2012 Hiroshi Miura <miurahr@osmf.jp>
// Copyright 2012 OpenStreetMap Foundation Japan
//

import java.util.*;
import java.util.logging.Logger;
import java.util.logging.Level;
import java.util.logging.FileHandler;
import java.util.logging.Handler;
import java.util.logging.Formatter;
import java.util.logging.LogRecord;

import org.xml.sax.helpers.XMLFilterImpl;
import org.xml.sax.XMLReader;
import org.xml.sax.Attributes;
import org.xml.sax.SAXException;
import org.xml.sax.helpers.AttributesImpl;

public final class MapFeaturesFilter extends XMLFilterImpl {

    private Properties configuration;
    private Stack <String>elements;
    private Stack <String>featureKeys;
    private String featureKey;
    private String elemName;
    private Logger logger;

    private boolean help_processed = false;

    /**
     * Constructor
     * @param parent base XMLReader
     * @throws SAXException
     */
    public MapFeaturesFilter(XMLReader parent, Properties configuration, String logFile) throws SAXException {
        super(parent);
        this.configuration = configuration;

        try {
            logger = Logger.getLogger(this.getClass().getName());
            logger.setUseParentHandlers(false);
            FileHandler fh = new FileHandler(logFile, true);
            fh.setFormatter(new Formatter() {
                @Override
                public String format(LogRecord record) {
                    return record.getMessage()+"\n";
                }
            });
            logger.addHandler(fh);
        }
        catch (java.io.IOException e) {
            System.err.println("IOException : " + e.getMessage());
        }
    }

    public void startDocument() throws SAXException
    {
        elements = new Stack<String>();
        featureKeys = new Stack<String>();
        featureKey = null;
        elemName = null;
        super.startDocument();
    }

    public void endDocument() throws SAXException
    {
        super.endDocument();
    }

    private AttributesImpl replaceAtts(AttributesImpl newatts, String featureKey, String tag) {
        String localizedName = configuration.getProperty(featureKey + "." + tag);
	int index = newatts.getIndex(tag);
        if (index >= 0) {
            if (localizedName != null) {
                newatts.setValue(index, localizedName);
            } else {
                String newkey = featureKey+"."+tag;
                // colon sign in properties should be escaped.
                logger.log(Level.INFO, newkey.replace(":","\\:")+"="+newatts.getValue(index));
            }
        }
        return newatts;
    }

    private String getAttsValue(Attributes atts, String name) {
        String result = null;

        for (int i=0;i<atts.getLength();i++) {
            String aname = atts.getQName(i);
            if (aname.equals(name)) {
                result = atts.getValue(i);
            }
        }

        return result;
    }

    /**
     * startElement handler
     * @param uri namespace
     * @param localName
     * @param qName
     * @param atts attributes
     * @throws SAXException
     */
    public final void startElement(String uri, String localName, String qName, Attributes atts) throws SAXException {

        elements.push(qName); // trace all elements on stack

        for (int i=0;i<atts.getLength();i++) {
            String aname = atts.getQName(i);
            if (aname.equals("id")) {
                featureKey = atts.getValue(i);
                featureKeys.push(featureKey); // trace all attribute keys on stack
                elemName = qName;
            }
        }

        AttributesImpl newatts = new AttributesImpl(atts);
        if (featureKey != null) {
            if (elemName == qName) { // when element that have "id" attribute
                if (elemName.equals("category")) {
                    newatts = replaceAtts(newatts, featureKey, "name");
                } else if (elemName.equals("feature")) {
                    newatts = replaceAtts(newatts, featureKey, "name");
                }
            } else if (qName.equals("input")) {
                String inputKey = getAttsValue(newatts, "key");
                if (inputKey != null) {
                    featureKeys.push(featureKey);
                    elemName = qName;
                    featureKey = featureKey + "." + inputKey;
                    newatts = replaceAtts(newatts, featureKey, "name");
                    newatts = replaceAtts(newatts, featureKey, "description");
                }
            } else if (qName.equals("choice")) {
                String choiceKey = getAttsValue(newatts, "value");
                if (choiceKey != null) {
                    newatts = replaceAtts(newatts, featureKey + "." + choiceKey, "text");
                }
            } else if (qName.equals("icon")) {
                newatts = replaceAtts(newatts, featureKey + ".icon", "image");
            }
        }
        super.startElement(uri, localName, qName, newatts);
    }
    
    /**
     * @param ch
     * @param start
     * @param length
     * @throws SAXException
     */
    public final void characters(char[] ch, int start, int length) throws SAXException {

        if ("help".equals(elements.peek())) {
            String helpuri = configuration.getProperty(featureKey + ".help");
            if (helpuri != null && !help_processed) {
                help_processed = true;
                char newch[] = helpuri.toCharArray();
                super.characters(newch, 0, newch.length);
                return;
            }
        }
        super.characters(ch, start, length);
        return;
    }

    /**
     * @param uri
     * @param localName
     * @param qName
     * @throws SAXException
     */
    public final void endElement(String uri, String localName, String qName) throws SAXException {
        String popedElem = elements.pop();
        if (elemName != null) {
            if (elemName.equals(popedElem)) {
                if (elemName.equals("help")) {
                    help_processed = false;
                }
                elemName = null;
                featureKey = featureKeys.pop();
            }
        }
        super.endElement(uri, localName, qName);
    }
}
