/*-------------------------------------------------------------------------
 *
 * http-service.
 *
 *	  Definitions for HTTP service file
 *
 * Portions Copyright (c) 1996-2026, PostgreSQL Global Development Group
 * Portions Copyright (c) 1994, Regents of the University of California
 *
 * src/interfaces/libpq-oauth/oauth-curl.h
 *
 *-------------------------------------------------------------------------
 */

#ifndef HTTP_SERVICE_H
#define HTTP_SERVICE_H

#include "libpq-fe.h"

/* Exported flow callback. */

extern PGDLLEXPORT int
parse_service_file_curl(const char *serviceFile,
					    const char *service,
					    PQconninfoOption *options,
					    PQExpBuffer errorMessage,
					    bool *group_found);


#endif							/* HTTP_SERVICE_H */
