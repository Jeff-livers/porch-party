export default {
  async fetch(request, env) {
    const asset = await env.ASSETS.fetch(request);
    const rangeHeader = request.headers.get('Range');
    if (asset.status !== 200 || !rangeHeader) return withAcceptRanges(asset);

    const body = await asset.arrayBuffer();
    const range = parseByteRange(rangeHeader, body.byteLength);
    const headers = new Headers(asset.headers);
    headers.set('Accept-Ranges', 'bytes');

    if (range === null) {
      return new Response(body, { status: 200, headers });
    }
    if (range === 'unsatisfiable') {
      headers.set('Content-Range', `bytes */${body.byteLength}`);
      headers.delete('Content-Length');
      return new Response(null, { status: 416, headers });
    }

    const { start, end } = range;
    headers.set('Content-Range', `bytes ${start}-${end}/${body.byteLength}`);
    headers.set('Content-Length', String(end - start + 1));
    return new Response(body.slice(start, end + 1), { status: 206, headers });
  },
};

function withAcceptRanges(response) {
  const copy = new Response(response.body, response);
  copy.headers.set('Accept-Ranges', 'bytes');
  return copy;
}

function parseByteRange(header, size) {
  const match = /^bytes=(\d*)-(\d*)$/.exec(header.trim());
  if (!match || (match[1] === '' && match[2] === '')) return null;

  let start;
  let end;
  if (match[1] === '') {
    start = Math.max(size - Number(match[2]), 0);
    end = size - 1;
  } else {
    start = Number(match[1]);
    end = match[2] === '' ? size - 1 : Math.min(Number(match[2]), size - 1);
  }

  if (start >= size || start > end) return 'unsatisfiable';
  return { start, end };
}
