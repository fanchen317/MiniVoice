// Artwork is selected and authorized by each host before this response is made.
// The renderer can then analyze those same pixels in a canvas.
const artworkScheme={scheme:'minivoice-art',privileges:{standard:true,secure:true,supportFetchAPI:true,corsEnabled:true}};
function artworkResponse(response){
 const headers=new Headers(response.headers);headers.set('Access-Control-Allow-Origin','*');
 return new Response(response.body,{status:response.status,statusText:response.statusText,headers});
}
module.exports={artworkScheme,artworkResponse};
