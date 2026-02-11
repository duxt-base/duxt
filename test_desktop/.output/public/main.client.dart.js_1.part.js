((a,b)=>{a[b]=a[b]||{}})(self,"$__dart_deferred_initializers__")
$__dart_deferred_initializers__.current=function(a,b,c,$){var J,B,E,A={
i5(d,e,f){var w=new A.bR(d,e,d,B.am(f.h("~(0)")),B.am(x.u),B.am(x.c),f.h("bR<0>"))
w.bz(d)
return w},
bR:function bR(d,e,f,g,h,i,j){var _=this
_.f=d
_.r=e
_.w=!1
_.y=null
_.a=f
_.b=g
_.c=h
_.d=i
_.$ti=j},
ib(d){return new A.hz(d)},
hz:function hz(d){this.a=d},
ji(d){var w=null
switch(d){case!0:w="true"
break
case!1:w="false"
break
case null:case void 0:break}return w},
cO:function cO(d,e,f,g,h,i,j,k,l,m,n,o,p,q,r){var _=this
_.c=d
_.d=e
_.e=f
_.f=g
_.r=h
_.w=i
_.x=j
_.y=k
_.z=l
_.Q=m
_.as=n
_.at=o
_.ax=p
_.a=q
_.$ti=r},
eh:function eh(d,e,f,g,h,i,j,k){var _=this
_.c=d
_.d=e
_.e=f
_.f=g
_.r=h
_.w=i
_.x=j
_.a=k},
ek:function ek(d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s,t,u,v,w,a0){var _=this
_.c=d
_.d=e
_.e=f
_.f=g
_.r=h
_.w=i
_.x=j
_.y=k
_.z=l
_.Q=m
_.as=n
_.at=o
_.ax=p
_.ay=q
_.ch=r
_.CW=s
_.cx=t
_.cy=u
_.db=v
_.dx=w
_.a=a0},
kj(){return new A.aq(null)},
aq:function aq(d){this.a=d},
dN:function dN(d){this.d=d
this.c=null},
fn:function fn(){},
fg:function fg(){},
ff:function ff(){},
fi:function fi(){},
fh:function fh(){},
fk:function fk(){},
fj:function fj(){},
fl:function fl(){},
fm:function fm(){},
fe:function fe(d){this.a=d},
lX(d){var w,v=d.toLowerCase()
$label0$0:{if("button"===v){w=D.u
break $label0$0}if("checkbox"===v){w=D.i
break $label0$0}if("color"===v){w=D.v
break $label0$0}if("date"===v){w=D.j
break $label0$0}if("datetime-local"===v){w=D.h
break $label0$0}if("email"===v){w=D.w
break $label0$0}if("file"===v){w=D.k
break $label0$0}if("hidden"===v){w=D.x
break $label0$0}if("image"===v){w=D.y
break $label0$0}if("month"===v){w=D.z
break $label0$0}if("number"===v){w=D.l
break $label0$0}if("password"===v){w=D.A
break $label0$0}if("radio"===v){w=D.m
break $label0$0}if("range"===v){w=D.B
break $label0$0}if("reset"===v){w=D.C
break $label0$0}if("search"===v){w=D.D
break $label0$0}if("submit"===v){w=D.E
break $label0$0}if("tel"===v){w=D.F
break $label0$0}if("text"===v){w=D.G
break $label0$0}if("time"===v){w=D.H
break $label0$0}if("url"===v){w=D.I
break $label0$0}if("week"===v){w=D.J
break $label0$0}w=null
break $label0$0}return w},
iD(d,e){var w=null,v=C.b8(d,w)
return new A.eh(w,w,e,C.aH(w),w,w,v,w)}},F,C,D
J=c[1]
B=c[0]
E=c[2]
A=a.updateHolder(c[3],A)
F=c[6]
C=c[5]
D=c[7]
A.bR.prototype={
K(d){var w=this
w.$ti.c.a(d)
J.a9(d,w.f)
w.bz(d)
w.bi(d)},
a0(){if(!this.w){this.w=!0
this.aZ()}},
a_(){var w=this
w.w=!1
w.y=null
w.bi(w.f)},
bz(d){var w,v,u,t=this
t.$ti.c.a(d)
t.y=null
for(w=t.r,v=0;v<1;++v){u=w[v].$1(d)
if(u!=null){t.y=u
break}}}}
A.cO.prototype={
H(d){var w,v=this,u=x.w,t=B.L(u,u)
t.C(0,v.at)
w=v.c
w=w==null?null:w.c
if(w!=null)t.k(0,"type",w)
t.k(0,"value",v.e)
w=A.ji(v.r)
if(w!=null)t.k(0,"checked",w)
w=A.ji(v.w)
if(w!=null)t.k(0,"indeterminate",w)
u=B.L(u,x.a)
u.C(0,v.ax)
u.C(0,C.i4().$1$2$onChange$onInput(v.y,v.x,v.$ti.c))
return new B.O("input",v.z,v.Q,v.as,t,u,null,null)}}
A.eh.prototype={
H(d){var w=this,v=x.w
return new B.O("label",w.d,w.e,w.f,B.L(v,v),w.w,w.x,null)}}
A.ek.prototype={
H(d){var w,v=this,u=x.w,t=B.L(u,u)
t.k(0,"name",v.w)
t.k(0,"placeholder",v.x)
w=E.d.i(v.Q)
t.k(0,"rows",w)
w=B.L(u,x.a)
w.C(0,v.db)
w.C(0,C.i4().$1$2$onChange$onInput(v.ay,v.ax,u))
return new B.O("textarea",v.ch,v.CW,v.cx,t,w,v.dx,null)}}
A.aq.prototype={
bG(){return new A.dN(B.L(x.A,x.k))}}
A.dN.prototype={
bC(d){var w=null,v=x.F,u=C.N(w,B.f([C.ix(new B.B("Form Validation",w),"text-4xl font-bold text-white mb-4"),C.eS(new B.B("Using formField() with built-in validators",w),"text-gray-400")],v),"text-center mb-8"),t=B.f([],v)
if($.hA().$0())t.push(this.cu())
else t.push(this.ce())
return C.N(C.N(w,B.f([u,C.N(w,t,"rounded-xl p-6 bg-gray-900 border border-gray-800")],v),"max-w-lg mx-auto"),w,"py-12 px-4")},
cu(){var w=null
return C.N(w,B.f([C.N(new B.B("\u2713",w),w,"text-4xl mb-4"),C.iy(new B.B("Message Sent!",w),"text-2xl font-bold text-emerald-400 mb-2"),C.eS(new B.B("Thanks for reaching out.",w),"text-gray-400 mb-6"),C.bG(new B.B("Send Another",w),"px-4 py-2 bg-gray-800 text-gray-300 rounded-lg hover:bg-gray-700 transition-colors",new A.fn())],x.F),"text-center py-8")},
ce(){var w,v,u,t,s,r,q,p=null,o=$.bD()
o.aq()
w=o.a
v=o.w&&o.y!=null
w=this.cd(o.y,v,"Name",new A.ff(),new A.fg(),"Your name",w)
v=$.bA()
v.aq()
o=v.a
u=v.w&&v.y!=null
o=this.bs(v.y,u,"Email",new A.fh(),new A.fi(),"your@email.com","email",o)
u=A.iD(new B.B("Message",p),y.d)
v=B.eP(["blur",new A.fj()],x.w,x.a)
t=$.bC()
s=t.w&&t.y!=null?"border-red-500":"border-gray-700"
r=C.b8(p,p)
q=x.F
r=B.f([u,new A.ek(p,!1,p,!1,p,"message","Your message...",!1,!1,4,p,p,new A.fk(),p,p,"w-full px-3 py-2 bg-gray-800 border "+s+y.e,C.aH(p),p,v,r,p)],q)
if(t.w&&t.y!=null){v=t.y
r.push(C.N(new B.B(v==null?"":v,p),p,"mt-1 text-sm text-red-400"))}return C.N(p,B.f([w,o,C.N(p,r,p),C.N(p,B.f([C.bG(new B.B("Submit",p),"px-6 py-2 bg-emerald-600 text-white rounded-lg hover:bg-emerald-700 transition-colors font-medium",new A.fl()),C.bG(new B.B("Reset",p),"text-sm text-gray-500 hover:text-gray-300 transition-colors",new A.fm())],q),"flex items-center justify-between pt-2")],q),"space-y-4")},
bs(d,e,f,g,h,i,j,k){var w,v,u,t,s,r,q=null
x.q.a(h)
x.k.a(g)
w=A.iD(new B.B(f,q),y.d)
v=x.w
u=B.eP(["blur",new A.fe(g)],v,x.a)
t=e?"border-red-500":"border-gray-700"
s=A.lX(j)
r=C.aH(q)
v=B.L(v,v)
v.k(0,"placeholder",i)
w=B.f([w,new A.cO(s,q,k,!1,q,q,h,q,q,"w-full px-3 py-2 bg-gray-800 border "+t+y.e,r,v,u,q,x.h)],x.F)
if(e)w.push(C.N(new B.B(d==null?"":d,q),q,"mt-1 text-sm text-red-400"))
return C.N(q,w,q)},
cd(d,e,f,g,h,i,j){return this.bs(d,e,f,g,h,i,"text",j)}}
var z=a.updateTypes([])
A.hz.prototype={
$1(d){if(B.D(d).length===0)return this.a
return null},
$S:38}
A.fn.prototype={
$0(){$.bD().a_()
$.bA().a_()
$.bC().a_()
$.hA().K(!1)},
$S:0}
A.fg.prototype={
$1(d){B.D(d)
return $.bD().K(d)},
$S:4}
A.ff.prototype={
$0(){return $.bD().a0()},
$S:0}
A.fi.prototype={
$1(d){B.D(d)
return $.bA().K(d)},
$S:4}
A.fh.prototype={
$0(){return $.bA().a0()},
$S:0}
A.fk.prototype={
$1(d){B.D(d)
return $.bC().K(d)},
$S:4}
A.fj.prototype={
$1(d){B.x(d)
return $.bC().a0()},
$S:2}
A.fl.prototype={
$0(){var w,v,u=$.bD()
u.a0()
w=$.bA()
w.a0()
v=$.bC()
v.a0()
if(u.y==null&&w.y==null&&v.y==null)$.hA().K(!0)},
$S:0}
A.fm.prototype={
$0(){$.bD().a_()
$.bA().a_()
$.bC().a_()},
$S:0}
A.fe.prototype={
$1(d){B.x(d)
return this.a.$0()},
$S:2};(function inheritance(){var w=a.inherit,v=a.inheritMany
w(A.bR,C.V)
v(B.aa,[A.hz,A.fg,A.fi,A.fk,A.fj,A.fe])
v(C.P,[A.cO,A.eh,A.ek])
w(A.aq,C.ao)
w(A.dN,C.aY)
v(B.aP,[A.fn,A.ff,A.fh,A.fl,A.fm])})()
B.fN(b.typeUniverse,JSON.parse('{"bR":{"V":["1"],"cf":["1"]},"cO":{"P":[],"l":[]},"eh":{"P":[],"l":[]},"ek":{"P":[],"l":[]},"aq":{"ao":[],"l":[]},"dN":{"a7":["aq"],"a7.T":"aq"}}'))
var y={e:" rounded-lg text-white placeholder-gray-500 focus:outline-none focus:border-emerald-500",d:"block text-sm font-medium text-gray-300 mb-1"}
var x={c:B.u("iv"),F:B.u("n<l>"),u:B.u("cf<@>"),A:B.u("V<@>"),w:B.u("b"),h:B.u("cO<b>"),k:B.u("~()"),a:B.u("~(m)"),q:B.u("~(b)")};(function constants(){var w=a.makeConstList
F.aq=w([],B.u("n<b?(j?)>"))})();(function lazyInitializers(){var w=a.lazyFinal
w($,"ni","bD",()=>A.i5("",B.f([A.ib("Name is required")],B.u("n<b?(b)>")),x.w))
w($,"ne","bA",()=>A.i5("",B.f([A.ib("Email is required")],B.u("n<b?(b)>")),x.w))
w($,"nh","bC",()=>A.i5("",B.f([A.ib("Message is required")],B.u("n<b?(b)>")),x.w))
w($,"nk","hA",()=>C.jH(!1,B.u("aj")))})()};
(a=>{a["2GNxPbWRdSvz4FRpzkHJvMLBfUs="]=a.current})($__dart_deferred_initializers__);
//# sourceMappingURL=main.client.dart.js_1.part.js.map
