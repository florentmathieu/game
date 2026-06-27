// Convertit des Markdown en PDF via le chromium fourni. Couvre titres, tableaux,
// citations, listes, gras/italique, code inline, règles — soit tout ce qu'utilisent nos docs.
import { chromium } from '/opt/node22/lib/node_modules/playwright/index.mjs';
import fs from 'fs';
import path from 'path';

const esc = s => s.replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;');
function inline(s){
  s = esc(s);
  s = s.replace(/`([^`]+)`/g, (_,c)=>`<code>${c}</code>`);
  s = s.replace(/\*\*([^*]+)\*\*/g, '<strong>$1</strong>');
  s = s.replace(/(^|[^*])\*([^*]+)\*(?!\*)/g, '$1<em>$2</em>');
  s = s.replace(/\[([^\]]+)\]\(([^)]+)\)/g, '<a href="$2">$1</a>');
  return s;
}
function cells(line){ let l=line.trim().replace(/^\|/,'').replace(/\|$/,''); return l.split('|').map(c=>c.trim()); }

function mdToHtml(md){
  const lines = md.replace(/\r/g,'').split('\n');
  let out=[], i=0;
  const flushList = (tag,items)=>{ if(items.length){ out.push(`<${tag}>`+items.map(x=>`<li>${inline(x)}</li>`).join('')+`</${tag}>`); } };
  while(i<lines.length){
    let line = lines[i];
    if(/^\s*$/.test(line)){ i++; continue; }
    // table
    if(/^\s*\|/.test(line) && i+1<lines.length && /^\s*\|?[\s:|-]+\|?\s*$/.test(lines[i+1]) && lines[i+1].includes('-')){
      const head = cells(line); i+=2; const rows=[];
      while(i<lines.length && /^\s*\|/.test(lines[i])){ rows.push(cells(lines[i])); i++; }
      out.push('<table><thead><tr>'+head.map(h=>`<th>${inline(h)}</th>`).join('')+'</tr></thead><tbody>'+
        rows.map(r=>'<tr>'+r.map(c=>`<td>${inline(c)}</td>`).join('')+'</tr>').join('')+'</tbody></table>');
      continue;
    }
    let m;
    if(m=line.match(/^(#{1,6})\s+(.*)$/)){ out.push(`<h${m[1].length}>${inline(m[2])}</h${m[1].length}>`); i++; continue; }
    if(/^\s*([-*])\s+\S/.test(line)){ const items=[]; while(i<lines.length && /^\s*([-*])\s+/.test(lines[i])){ items.push(lines[i].replace(/^\s*[-*]\s+/,'')); i++; } flushList('ul',items); continue; }
    if(/^\s*\d+\.\s+\S/.test(line)){ const items=[]; while(i<lines.length && /^\s*\d+\.\s+/.test(lines[i])){ items.push(lines[i].replace(/^\s*\d+\.\s+/,'')); i++; } flushList('ol',items); continue; }
    if(/^\s*>/.test(line)){ const buf=[]; while(i<lines.length && /^\s*>/.test(lines[i])){ buf.push(lines[i].replace(/^\s*>\s?/,'')); i++; } out.push(`<blockquote>${inline(buf.join(' '))}</blockquote>`); continue; }
    if(/^\s*([-*_])\1{2,}\s*$/.test(line)){ out.push('<hr>'); i++; continue; }
    // paragraph (jusqu'à ligne vide / bloc)
    const buf=[]; while(i<lines.length && !/^\s*$/.test(lines[i]) && !/^\s*(#{1,6}\s|>|\||[-*]\s|\d+\.\s)/.test(lines[i]) && !/^\s*([-*_])\1{2,}\s*$/.test(lines[i])){ buf.push(lines[i]); i++; }
    out.push(`<p>${inline(buf.join(' '))}</p>`);
  }
  return out.join('\n');
}

const CSS = `
  body{font-family:-apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif;color:#1f2430;line-height:1.5;max-width:760px;margin:0 auto;padding:36px 40px;font-size:13px}
  h1{font-size:24px;border-bottom:2px solid #6b4f8a;padding-bottom:6px;margin-top:0}
  h2{font-size:18px;border-bottom:1px solid #d8cce6;padding-bottom:4px;margin-top:26px;color:#3a2d52}
  h3{font-size:15px;margin-top:18px;color:#4a3a66}
  p{margin:8px 0}
  table{border-collapse:collapse;width:100%;margin:12px 0;font-size:12px}
  th,td{border:1px solid #cdb8e0;padding:5px 8px;text-align:left;vertical-align:top}
  th{background:#efe7f6}
  tr:nth-child(even) td{background:#faf7fd}
  blockquote{margin:12px 0;padding:8px 14px;border-left:4px solid #8a6db5;background:#f5f0fa;border-radius:0 4px 4px 0}
  code{background:#efeaf4;padding:1px 5px;border-radius:3px;font-family:Menlo,Consolas,monospace;font-size:11px}
  ul,ol{margin:8px 0;padding-left:24px}
  li{margin:3px 0}
  hr{border:none;border-top:1px solid #d8cce6;margin:20px 0}
  a{color:#6b4f8a}
`;

const files = process.argv.slice(2);
const browser = await chromium.launch({executablePath:'/opt/pw-browsers/chromium-1194/chrome-linux/chrome'});
for(const f of files){
  const md = fs.readFileSync(f,'utf8');
  const html = `<!doctype html><html lang="fr"><head><meta charset="utf-8"><style>${CSS}</style></head><body>${mdToHtml(md)}</body></html>`;
  const page = await browser.newPage();
  await page.setContent(html, {waitUntil:'networkidle'});
  const pdf = f.replace(/\.md$/,'.pdf');
  await page.pdf({path:pdf, format:'A4', printBackground:true, margin:{top:'14mm',bottom:'14mm',left:'12mm',right:'12mm'}});
  await page.close();
  console.log('→', pdf);
}
await browser.close();
