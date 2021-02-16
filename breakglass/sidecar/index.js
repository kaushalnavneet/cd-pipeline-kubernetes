/**
 * Licensed Materials - Property of IBM
 * (c) Copyright IBM Corporation 2020. All Rights Reserved.
 *
 * Note to U.S. Government Users Restricted Rights:
 * Use, duplication or disclosure restricted by GSA ADP Schedule
 * Contract with IBM Corp.
 */
'use strict';

require('app-module-path/register');

const express = require('express'),
    bodyParser = require('body-parser'),
    compression = require('compression'),
    log4js = require('log4js'),
    StandardError = require("errors/StandardError"),
    config = require('config'),
    nconf = require('nconf');

    const logger = log4js.getLogger('index');

config.configureNconf();
const startup = async() => {
    // configure express
    const app = express();

    app
    //middleware
    .use(compression())
    .use(bodyParser.json({limit: '1mb'}))
    //routes
    .use('/v1/tekton-pipelines', require('./controllers/api'))
 
    // route catch-all
    .use((req, res, next) => {
        return next(new StandardError({}, {
            message: `Route '${ req.url }' doesn't exist.`, 
            status: 404
        }));
    })

    // errors
    .use((err, req, res, next) => {
        if (res.headersSent) {
            return next(err);
        }

        let error;
        if (err instanceof StandardError) {
            error = err;
        } else if (err.status || err.statusCode) {
            const status = err.status || err.statusCode;
            const errorObject = {
                message: err.message,
                status: status,
                code: err.type,
                tags: ['non-standard']
            };
            const responseObject = {};
            if (err.expose) {
                responseObject.message = err.message;
                responseObject.status = status;
            }
            error = new StandardError(errorObject, responseObject);
        } else {
            // npe or other unexpected error
            error = new StandardError({
                stack: err.stack,
                tags: ['unknown']
            });
        }
        error.response.status = error.response.status || 500;
        error.response.message = error.response.message || "Unknown";

        const responseBody = {};
        
        responseBody.errors = [{
            ...(error.response.code && {code: error.response.code}),
            detail: error.response.message
        }];
    

        res.status(String(error.response.status)).json(responseBody);
    });
    

    // start server
    app.listen(nconf.get('PORT'), () => {
        console.log("Listening on port " + nconf.get('PORT'));
    });
    
};

startup();
