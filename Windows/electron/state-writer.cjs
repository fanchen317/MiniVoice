// At most one queued snapshot; capture latest state when the write starts.
function coalescedWriter({snapshot,write}){let writes=Promise.resolve(),pending=false;return()=>{if(!pending){pending=true;writes=writes.catch(()=>{}).then(async()=>{pending=false;await write(snapshot());});}return writes;};}
module.exports={coalescedWriter};
