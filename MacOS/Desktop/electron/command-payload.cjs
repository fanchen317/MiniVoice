// Metadata can contain a 20 MiB image encoded as base64; other commands retain
// their existing 4 MiB boundary. The backend still validates decoded image data.
function validCommandPayload(action,payload){return payload!==null&&typeof payload==='object'&&!Array.isArray(payload)&&JSON.stringify(payload).length<=(action==='saveMetadata'?32:4)*1024*1024;}
module.exports={validCommandPayload};
