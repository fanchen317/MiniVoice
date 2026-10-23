export function contentViolations(source,file){
 const errors=[];
 if(!file.endsWith('/components/ActionButton.jsx')&&/<button\b/.test(source))errors.push('内容按钮必须使用 ActionButton');
 if(/<select\b/.test(source))errors.push('选择控件必须使用 Choice');
 if(/<input\b[^>]*\btype\s*=\s*(?:["']|\{\s*["'])(?:range|checkbox|radio|number|file|date|time|color)["']/s.test(source))errors.push('不得直接使用原生外观输入控件；使用自有控件或平台文件适配器');
 if(/\b(?:window|globalThis)\.(?:alert|confirm|prompt)\s*\(/.test(source))errors.push('应用内容确认必须使用自有弹窗');
 return errors;
}

// Deliberately a direct-reference guard, not a JavaScript dependency-graph audit.
export function componentViolations(source,file){
 if(!file.startsWith('Shared/UI/src/components/'))return [];
 const errors=[];
 const imports=[...source.matchAll(/\b(?:import|export)\s+(?:[^;'"\n]*?\s+from\s*)?['"]([^'"]+)['"]|\bimport\s*\(\s*['"]([^'"]+)['"]\s*\)/g)];
 for(const match of imports){
  const specifier=match[1]||match[2];
  // Parent-level dependencies are explicitly reviewed pure models, not pages/bridges.
  if(!['react','react-dom','../presentation.js','../editorTools.js'].includes(specifier)&&!/^\.\/(?!.*(?:^|\/)\.\.\/)/.test(specifier))errors.push(`组件不得依赖页面、平台或未审查模块：${specifier}`);
 }
 if(/\b(?:MiniVoiceHost|miniVoice|localStorage|sessionStorage|indexedDB)\b|\b(?:fetch|XMLHttpRequest|WebSocket)\s*\(/.test(source))errors.push('共享组件不得直接调用宿主、网络或持久化服务；由调用方注入语义事件');
 return errors;
}
