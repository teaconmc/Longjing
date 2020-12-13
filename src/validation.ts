class CheckedError extends Error {}

export function check(condition: boolean, message?: string) {
  if (!condition) throw new CheckedError(message || 'Internal Server Error')
}

export async function handleError(error: Error): Promise<Response> {
  const message = error instanceof CheckedError ? error.message : 'Internal Server Error'
  return new Response(JSON.stringify({ success: false, error: message }), { status: 500 })
}
