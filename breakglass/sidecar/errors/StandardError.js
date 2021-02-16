/**
 * Licensed Materials - Property of IBM
 * (c) Copyright IBM Corporation 2018. All Rights Reserved.
 *
 * Note to U.S. Government Users Restricted Rights:
 * Use, duplication or disclosure restricted by GSA ADP Schedule
 * Contract with IBM Corp.
 */

'use strict';

class StandardError extends Error {

    /**
     * StandardError class - The constructor should be provided with at a
     * minimum: an error message, an error stack or a response message.
     *
     * @param {String} error.message - Error message
     * @param {String} error.status - Error status code
     * @param {String} error.code - Error code
     * @param {String} error.stack - Error stack
     * @param {String} error.tags - Error tags (used when logging error)
     *
     * @param {String} response.message - Response message
     * @param {String} response.status - Response status code
     * @param {String} response.code - Response error code
     */
    constructor(error = {}, response = {}) {
        let message = error.message || response.message;
        if (message instanceof Object) {
            message = JSON.stringify(message, null, 3);
        }
        super(message);

        // Maintains proper stack trace for where our error was thrown
        if (error.stack) {
            this.stack = error.stack;
        } else if (Error.captureStackTrace) {
            Error.captureStackTrace(this, StandardError);
        }

        this.status = parseInt(error.status);
        this.code = error.code;
        this.tags = error.tags || [];

        this.response = response;
    }
}

module.exports = StandardError;
