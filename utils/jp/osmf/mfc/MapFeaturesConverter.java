package jp.osmf.mfc;

//
// Utility to generate localized map_features.xml and map_features/feature.xml
//
// Copyright 2012 Hiroshi Miura <miurahr@osmf.jp>
// Copyright 2012 OpenStreetMap Foundation Japan
//

import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.util.Properties;
import java.util.logging.*;

import javax.xml.transform.Result;
import javax.xml.transform.Source;
import javax.xml.transform.Transformer;
import javax.xml.transform.TransformerFactory;
import javax.xml.transform.sax.SAXSource;
import javax.xml.transform.stream.StreamResult;

import org.xml.sax.InputSource;
import org.xml.sax.SAXException;
import org.xml.sax.helpers.XMLReaderFactory;

public class MapFeaturesConverter {

    public static final void main(String[] args) {

        String sourceFile = "";
        String destFile = "";
        String propertiesFile = "";
        String logFile = "";
        File inputFile;
        File outputFile;

        if (args.length > 3) {
            sourceFile = args[0];
            destFile = args[1];
            propertiesFile = args[2];
            logFile = args[3];
        } else {
            System.err.println("java -jar MapFeaturesConverter.jar <source> <dest> <properties> <log>");
            System.exit(1);
        }

        try {
            inputFile = new File(sourceFile);
            outputFile = new File(destFile);

            InputStream propInputStream = new FileInputStream(new File(propertiesFile));
            Properties configuration = new Properties();
            configuration.load(new InputStreamReader(propInputStream, "UTF-8"));

            MapFeaturesFilter filter = new MapFeaturesFilter(XMLReaderFactory.createXMLReader(), configuration, logFile);
            TransformerFactory factory = TransformerFactory.newInstance();
            Transformer transformer = factory.newTransformer();

            Source source = new SAXSource(filter, new InputSource(new FileInputStream(inputFile)));
            Result result = new StreamResult(outputFile);

            transformer.transform(source, result);
        }
        catch (javax.xml.transform.TransformerFactoryConfigurationError e) {
            System.err.println("TransformerFactoryConfigurationError : " + e.getMessage());
        }
        catch (javax.xml.transform.TransformerConfigurationException e) {
            System.err.println("TransformerConfigurationException : " + e.getMessage());
        }
        catch (javax.xml.transform.TransformerException e) {
            System.err.println("TransformerException : " + e.getMessage());
        }
        catch (SAXException e) { 
            System.err.println("SAXException : " + e.getMessage());
        }
        catch (java.io.IOException e) { 
            System.err.println("IOException : " + e.getMessage());
        }
    }
}


