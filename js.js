/* 
todo 
 settings
 fullscreen 3d maze
  stereo sbs?
*/

const win='rgb(255,0,0)';
const wall='rgb(0,0,0)';
const draw='rgb(123,123,123)';
const wd = document.getElementById("wd");
const ht = document.getElementById("ht");
const bg = document.getElementById("bg");
const sp = document.getElementById("sp");
const td = document.getElementById("td");
const st = document.getElementById("st");
const ctx = bg.getContext("2d");
const spr = sp.getContext("2d");
const tdc = td.getContext("2d");
const rect = bg.getBoundingClientRect();
document.getElementById("start").onclick = function(){ ngm(); }
document.getElementById("tsetup").onclick = function(){
 var cirtog=document.getElementById("togsetup");
 if (cirtog.style.display !== "none") { cirtog.style.display = "none"; }
 else {  cirtog.style.display = "block"; }
}
document.getElementById("thelp").onclick = function(){
 var cirtog=document.getElementById("toghelp");
 if (cirtog.style.display !== "none") { cirtog.style.display = "none"; }
 else {  cirtog.style.display = "block"; }
}

 //rows, odd numbers work better  range 9-89 
//var gsz=((Math.random()*10)+9)|0;
var fini=0; // found exit
var gsz=wd.value*1;
gsz = gsz+(1-gsz%2);

window.addEventListener("focus", strtm);
window.addEventListener("blur", stptm);
sp.onclick = mmove;
//window.addEventListener("deviceorientation", hO, true);

var w=(window.innerWidth-bg.getBoundingClientRect().left*2)/2.4; //fix scale later!
var h=w; 
//var h=window.innerHeight-c1.getBoundingClientRect().top-20;

//var sz=Math.floor(w/gsz);//blk sz
var sz=w/gsz;//blk sz

//fill with wall
var grid = Array(gsz).fill().map(() => Array(gsz).fill(1));
//console.log(grid);
var pause=true;
//var xxx=0;
//var res=0;
//var iii=1;
var done=0;
var dbclk,ln;
var ww=Math.round(w/sz);
var www=Math.round(ww/2)-1;
var hh=Math.round(h/sz);
var hhh=Math.round(hh/2)-1;
var mx=1,my=1,prx=mx,pry=my;

setTimeout(function(){ start() }, 150);


ngm();

//funcs
 

function ngm() {
 //console.log('newgam');
 pause=true;
 if (done==1) { rctick(); }

 mx=1,my=1,prx=mx,pry=my;
 gsz=wd.value*1;
 if (gsz>99) { gsz=99; wd.value=gsz; }
 if (gsz<8) { gsz=8; wd.value=gsz; }
 gsz = gsz+(1-gsz%2);
 sz=w/gsz;//blk sz
 //fill with wall
 grid = Array(gsz).fill().map(() => Array(gsz).fill(1));
 worldMap=grid;
 ww=Math.round(w/sz);
 www=Math.round(ww/2)-1;
 hh=Math.round(h/sz);
 hhh=Math.round(hh/2)-1;
 mx=1,my=1,prx=mx,pry=my;

 spx=Math.floor(sz+(sz/2));
 spy=spx;
 mv=Math.floor(sz/4);
 bg.width = w;
 sp.width = w;
 td.width = w;
 st.width = w;
 bg.height = h;
 sp.height = h;
 td.height = h;
 st.height = h;
 bg.style.left=w+td.getBoundingClientRect().left;
 sp.style.left=w+td.getBoundingClientRect().left;
 st.style.left=w+td.getBoundingClientRect().left;
 posX = 1.5, posY = 1.5, dirX = -1, dirY = 0,planeX = 0, planeY = .5;

 fini=0; // found exit

 //bg.style.display='none';
 //sp.style.display='none';

 cord=[];
 for (tx=1;tx<=www;tx++) {
  for (ty=1;ty<=hhh;ty++) {
  //coords += '('+tx+'x'+ty+')';
   cord.push(tx+'x'+ty);
  }
 }
 cord.sort(function(a, b){return 0.5 - Math.random()});
 x=Math.floor(www/2);y=Math.floor(hhh/2);
 px=x;py=y;
 ln=100;i=0;dc=0;dr=1;ti=0;
 
 ctx.fillStyle = wall;
 ctx.fillRect(0, 0, w, h); //background

 done=0; 
 while (done!=1) { godb(); }
 if (typeof fps!="undefined") {
  setTimeout(function(){ start() }, 150);
  setTimeout(function(){ rcstart() }, 250);
 }
 return;
}
function remAry(array, item){
 for(var i in array){
  if(array[i]==item){
   array.splice(i,1);
   break;
  }
 }
}
function strgm() {
 //console.log('start game');
 //xxx=0;
 //zz=0;
 //clearTimeout(dbclk);
 //dbclk=setInterval(function(){godb();}, 40);
 //return;
}
function strtm() {
 //console.log('start');
 pause=false;
 //console.log('rct',typeof rctick);
 if (done==1 && typeof rctick!='undefined') { rctick(); }
}
function stptm() {
 //clearTimeout(dbclk);
 //console.log('stop');
 pause=true;
 //dbclk=null;
 return;
}

function mmove(e) {
	//mx=e.pageX;
	//my=e.pageY;
 mx= e.clientX - rect.left;
 my= e.clientY - rect.top;
 //for (qq=0;qq<gsz;qq++){
 // console.log(qq, grid[qq]);
 //}
 //start();
}
function tpxm(x,y) {
 out=0;
 pxl = ctx.getImageData(x,y, 1, 1).data;
 temp='rgb('+pxl[0]+','+pxl[1]+','+pxl[2]+')';
 if (temp==win) { win=2;ctx.fillStyle =draw;ctx.fillRect(sz, sz, w-sz-sz,h-sz-sz);setTimeout(function(){window.location.reload(1);}, 3500); }
 if (temp!=draw) { out=1; }
 return out;
}
function tpxl(x,y,z) {
 out=0;
 pxl = ctx.getImageData((x*2*sz)-(sz/2), (y*2*sz)-(sz/2), 1, 1).data;
 temp='rgb('+pxl[0]+','+pxl[1]+','+pxl[2]+')';
 if (temp==draw) { out=1; }
 if (z==0) {
  if (x<=0 || x>www) { out=1; }
  if (y<=0 || y>hhh) { out=1; }
 }
 return out;
}
/*
function hO(ev) {
 var absolute = ev.absolute;
 var alpha    = ev.alpha;
 var beta     = ev.beta;
 var gamma    = ev.gamma;
 //console.log(Math.round(beta),Math.round(gamma));
}
*/
function godb() {
 //console.log('cl',cord.length);
 if (cord.length==1) {
  if (done==1) { return; }
   tmp=cord[Math.floor(Math.random() *cord.length)];
   x=Number(tmp.substring(0,tmp.indexOf('x')));
   y=Number(tmp.substring(tmp.indexOf('x')+1,tmp.length));
   grid[y*2-1][x*2-1]=0;
   //console.log('srt');
   //start();
   
   setTimeout(function(){ rcstart() }, 400);
   //game.js

  //console.log(cord);
  done=1;
  //ctx.fillStyle =draw; ctx.fillRect(x*2*sz-sz, y*2*sz-sz,1*sz,1*sz); // ??
  x=2;y=1;//start pos
  ctx.fillStyle ='rgb(0,255,0)'; // draw start
  ctx.fillRect(x*sz-sz, y*sz-sz,sz,sz);
  x=www;y=hhh;
  ctx.fillStyle =win; // draw end
  ctx.fillRect(2*x*sz-sz, 2*y*sz,sz,sz);
  grid[y*2][x*2-1]=4;
  //strgm();
  //zz=0;
  return;
 }
 
  dl=tpxl(x-1,y,0) ? '' : '3';
  dl=tpxl(x+1,y,0) ? dl : dl+'1';
  dl=tpxl(x,y-1,0) ? dl : dl+'0';
  dl=tpxl(x,y+1,0) ? dl : dl+'2';
  if (dl.length==0) {
   //limit sampling, refresh
   //res++;
   //if (res>(hh*ww)/3) { console.log('No move');stptm();setTimeout(function(){window.location.reload(1);}, 30000); }
   
   //ctx.fillStyle =draw; //cover last marker
   //ctx.fillRect(x*2*sz-sz, y*2*sz-sz,1*sz,1*sz);
   
   tmp=cord[Math.floor(Math.random() *cord.length)];
   x=Number(tmp.substring(0,tmp.indexOf('x')));
   y=Number(tmp.substring(tmp.indexOf('x')+1,tmp.length));
   //console.log(x,y,cord);
   pxl='';
   while (!pxl) {
    for (ti=0;ti<4;ti++) {
     tx=x;ty=y;
     switch (ti) {
      case 0:
       ty--; break;
      case 1:
       tx++; break;
      case 2:
       ty++; break;
      case 3:
       tx--; break;
     }
     pxl=tpxl(tx,ty,1);
     if (pxl) {break;}
    }
    tmp=cord[Math.floor(Math.random() *cord.length)];
    x=Number(tmp.substring(0,tmp.indexOf('x'))); y= Number(tmp.substring(tmp.indexOf('x')+1,tmp.length));
   }
   x=tx;y=ty;
   px=x;py=y;
   return;
  }
  if (dc==0 && dl.length>1) { dl=dl.replace('2',''); }
  if (dc==1 && dl.length>1) { dl=dl.replace('3',''); }
  if (dc==2 && dl.length>1) { dl=dl.replace('0',''); }
  if (dc==3 && dl.length>1) { dl=dl.replace('1',''); }
  //console.log(dc);
  tmp=Math.log(www*hhh);
  dd=Math.floor(Math.random() * tmp); //base on grid size?
  tmp=dl.charAt(Math.floor(Math.random() * dl.length));
  // stay on path or change dir
  if (!dl.includes(dc.toString())) { dc=Number(tmp); }
  dc=dd>1 ? dc : Number(tmp);
  switch (dc) {
  case 0:
   y--; break;
  case 1:
   x++; break;
  case 2:
   y++; break;
  case 3:
   x--; break;
  }
  if (tpxl(x,y,0)) {
   x=px;y=py;
	  return;
  }
  if (x<1) { x=1;dc=Math.floor(Math.random() * 4); }
  if (y<1) { y=1;dc=Math.floor(Math.random() * 4); }
  if (x>www) { x=px;dc=Math.floor(Math.random() * 4); }
  if (y>hhh) { y=py;dc=Math.floor(Math.random() * 4); }
  //console.log(x,y);
  ctx.fillStyle =draw; //path

  if (dc==1) { //rt
   ctx.fillRect(px*2*sz-sz, py*2*sz-sz,1*sz+(sz*2),1*sz);
   grid[py*2-1][px*2]=0;
  } else if (dc==3) { //lf
   ctx.fillRect(x*2*sz-sz, y*2*sz-sz,1*sz+(sz*2),1*sz);
   grid[y*2-1][x*2]=0;
  } else if (dc==2) { //dn
   ctx.fillRect(px*2*sz-sz, py*2*sz-sz,1*sz,1*sz+(sz*2));
   grid[py*2][px*2-1]=0;
  } else if (dc==0) { //up
   ctx.fillRect(x*2*sz-sz, y*2*sz-sz,1*sz,1*sz+(sz*2));
   grid[y*2][x*2-1]=0;
  }
  //ctx.fillStyle ='rgb(0,55,0)'; // mark dead ends
  //ctx.fillRect(x*2*sz-sz, y*2*sz-sz,1*sz,1*sz); // ??
  //iii++;
  //console.log(x*2-1,y*2-1);
  rl=cord.length;
  remAry(cord,x+'x'+y);
  grid[y*2-1][x*2-1]=0;
  //console.log(grid);
  px=x;py=y;
 }
function getRndColor() {
 r = Math.floor(Math.random() * 56) +200;
 g = r;
 b=r-(Math.floor(Math.random() * 50)+50);
 return 'rgb(' + r + ',' + g + ',' + b + ')';
}