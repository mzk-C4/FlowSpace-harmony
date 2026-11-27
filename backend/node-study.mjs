// The map-edit model may revise narrative notes, but cannot silently remove or
// replace a separately confirmed node lesson/link/code attachment.
const marker='\n\n```flowspace-learning-v1\n';
export function preserveNodeStudy(previous,note){
 const index=previous.lastIndexOf(marker);
 if(index<0||!previous.endsWith('\n```'))return note;
 try{const data=JSON.parse(previous.slice(index+marker.length,-4));if(data.version!==1)return note}catch{return note}
 const next=typeof note==='string'?note:'';
 const start=next.indexOf(marker);
 return (start<0?next:next.slice(0,start))+previous.slice(index);
}
