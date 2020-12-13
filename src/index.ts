import { handleRequest } from './request'

import { handleError } from './validation'

addEventListener('fetch', (e) => e.respondWith(handleRequest(e.request).catch(handleError)))
