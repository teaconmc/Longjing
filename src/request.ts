import { toUint8Array, toBase64, fromUint8Array } from 'js-base64'

import { Octokit } from '@octokit/core'

import { check } from './validation'

declare const TEACON_BOT_APP_ID: string

declare const TEACON_BOT_PRIVATE_KEY: string

const pemRaw = toUint8Array(TEACON_BOT_PRIVATE_KEY.trim().split('\n').slice(1, -1).join(''))

const msgHeaders = toBase64(JSON.stringify({ alg: 'RS256', typ: 'JWT' }), true)

const sourceRegexp = /^https:\/\/github\.com\/[\w-.]+\/[\w-.]+\.git$/ // TODO: more platforms

const targetRegexp = /^TeaCon\d{4}$/

const algorithm = {
  name: 'RSASSA-PKCS1-v1_5',
  hash: { name: 'SHA-256' },
}

async function toJWT(payload: object) {
  const key = await crypto.subtle.importKey('pkcs8', pemRaw, algorithm, false, ['sign'])

  const msg = toBase64(JSON.stringify(payload), true)
  const msgRaw = toUint8Array(toBase64(msgHeaders + '.' + msg, true))
  const signatureRaw = await crypto.subtle.sign(algorithm, key, msgRaw.buffer)

  const msgFooter = fromUint8Array(new Uint8Array(signatureRaw), true)

  return msgHeaders + '.' + msg + '.' + msgFooter
}

async function getInstallationToken(jwtToken: string): Promise<string> {
  const octokitApp = new Octokit({ auth: jwtToken })

  const requestPre = await octokitApp.request('GET /app/installations')

  const teaconId = requestPre.data.find((i) => i.account && i.account.login === 'teaconmc')!.id

  const request = await octokitApp.request('POST /app/installations/{installation_id}/access_tokens', {
    installation_id: teaconId,
  })

  return request.data.token
}

async function doBuildCallbackTrigger(installationToken: string, target: string): Promise<void> {
  const octokitRepos = new Octokit({ auth: installationToken })

  const request = await octokitRepos.request('POST /repos/{owner}/{repo}/dispatches', {
    event_type: 'build_callback',
    owner: 'teaconmc',
    repo: target,
  })

  check(request.status === 204)
}

export async function handleRequest(request: Request): Promise<Response> {
  const method = request.method
  check(method === 'POST', 'Method should be POST')

  const url = new URL(request.url)
  check(url.pathname === '/build-callback', 'Unrecognized request path: ' + url.pathname)

  const { target, source } = await request.json()
  check(targetRegexp.test(target), 'Invalid target: ' + target)
  check(sourceRegexp.test(source), 'Invalid source: ' + source)

  const now = Math.floor(Date.now() / 1000)
  const jwtToken = await toJWT({ iat: now, exp: now + 600, iss: TEACON_BOT_APP_ID })

  try {
    const accessToken = await getInstallationToken(jwtToken)
    await doBuildCallbackTrigger(accessToken, target)
  } catch (e) {
    check(false, 'Failed to trigger repository because of network reasons: ' + target)
  }

  return new Response(JSON.stringify({ success: true }), { status: 200 })
}
