(()=>{
 const key='__universalMacTranslationV2';
 if(window[key])return;
 const originals=new Map();let pending=[],applied=[],selectionMode=false,token='';
 function eligible(n){const p=n.parentElement;return p&&!p.closest('script,style,noscript,textarea,input,select,option,code,pre,svg,math,[contenteditable]:not([contenteditable="false"]),[translate="no"],.notranslate')&&!p.isContentEditable;}
 function keep(nodes){if(!nodes.length)return;const r=document.createRange();r.setStart(nodes[0],0);r.setEnd(nodes.at(-1),nodes.at(-1).length);const s=getSelection();s.removeAllRanges();s.addRange(r);}
 function prune(){for(const[n,e]of originals)if(!n.isConnected||n.nodeValue!==e.translated)originals.delete(n);}
 window[key]={
 begin(next){
  token=next;pending=[];applied=[];prune();
  const s=getSelection();const r=s?.rangeCount&&!s.isCollapsed&&s.toString().trim()?s.getRangeAt(0).cloneRange():null;selectionMode=!!r;
  const w=document.createTreeWalker(document.body,NodeFilter.SHOW_TEXT);let n;const parts=[];
  while(n=w.nextNode()){
   if(!eligible(n)||(r&&!r.intersectsNode(n)))continue;
   const start=r&&n===r.startContainer?r.startOffset:0,end=r&&n===r.endContainer?r.endOffset:n.length;
   if(end>start&&n.nodeValue.slice(start,end).trim())parts.push({node:n,start,end,before:n.nodeValue});
  }
  const restore=r?parts.map(p=>p.node).filter(n=>originals.has(n)):[...originals.keys()];
  if(restore.length){for(const n of restore){n.nodeValue=originals.get(n).original;originals.delete(n);}if(r)keep(restore);return JSON.stringify({restored:true,selection:!!r,items:[]});}
  pending=parts.filter(p=>/[\p{L}\p{N}]/u.test(p.before.slice(p.start,p.end)));
  if(pending.length>5000)throw Error('Слишком большая страница; выделите фрагмент');
  return JSON.stringify({restored:false,selection:!!r,items:pending.map((p,id)=>({id,text:p.before.slice(p.start,p.end)}))});
 },
 apply(expected,id,text){
  if(token!==expected)throw Error('Перевод отменён');const p=pending[id];
  if(!p||!p.node.isConnected||p.node.nodeValue!==p.before)throw Error('Страница изменилась');
  const original=p.before.slice(p.start,p.end);if(text.trim()===original.trim())return 'unchanged';
  let n=p.node;if(p.end<n.length)n.splitText(p.end);if(p.start)n=n.splitText(p.start);
  const translated=original.match(/^\s*/)[0]+text.trim()+original.match(/\s*$/)[0];
  n.nodeValue=translated;originals.set(n,{original,translated});applied.push(n);return 'ok';
 },
 finish(expected){if(token!==expected)return 'cancelled';if(selectionMode)keep(applied);pending=[];return 'ok';},
 rollback(expected){if(token!==expected)return 'cancelled';for(const n of applied){const e=originals.get(n);if(e&&n.isConnected&&n.nodeValue===e.translated)n.nodeValue=e.original;originals.delete(n);}pending=[];applied=[];return 'ok';}
 };
})()
