/*
 * Retroid Pocket Nova M1/M2 permanent digital-to-trigger-axis translation.
 * Freestanding static ARM64 executable, MIT license.
 *
 * Reads EV_KEY 306/309 from the EXISTING Xbox Wireless Controller input event
 * device, and ALSO polls EVIOCGKEY state as an independent way of detecting
 * M1/M2 presses from the raw Default mode. Emits ABS_BRAKE (L2) / ABS_GAS (R2) into that SAME evdev
 * node on press/release, so there is no second/competing controller.
 *
 * Test: nova_m1m2_native_v3 /dev/input/eventN 30 trace
 * Boot: nova_m1m2_native_v3 /dev/input/eventN 0 quiet
 * Never EVIOCGRABs a device. Test is conditional and never persists on failure.
 */

typedef unsigned short u16;
typedef unsigned int u32;
typedef int s32;
typedef unsigned long usize;
typedef long slong;
typedef unsigned char u8;
struct input_event { slong sec, usec; u16 type, code; s32 value; };
struct pollfd { s32 fd; short events, revents; };
struct timespec { slong sec, nsec; };
#define SYS_openat 56
#define SYS_close 57
#define SYS_read 63
#define SYS_write 64
#define SYS_ioctl 29
#define SYS_ppoll 73
#define SYS_clock_gettime 113
#define AT_FDCWD -100
#define O_RDWR 2
#define O_NONBLOCK 2048
#define POLLIN 1
#define POLLERR 8
#define POLLHUP 16
#define EV_SYN 0
#define EV_KEY 1
#define EV_ABS 3
#define M1_PHYSICAL 306
#define M2_PHYSICAL 309
#define ABS_GAS 9
#define ABS_BRAKE 10
#define CLOCK_MONOTONIC 1
/* Linux input: EVIOCGKEY(64) = _IOC(_IOC_READ,'E',0x18,64) */
#define EVIOCGKEY64 0x80404518UL
static slong sc(slong nr, slong a0, slong a1, slong a2, slong a3, slong a4, slong a5){
    register slong x0 __asm__("x0")=a0;
    register slong x1 __asm__("x1")=a1;
    register slong x2 __asm__("x2")=a2;
    register slong x3 __asm__("x3")=a3;
    register slong x4 __asm__("x4")=a4;
    register slong x5 __asm__("x5")=a5;
    register slong x8 __asm__("x8")=nr;
    __asm__ volatile("svc #0" : "+r"(x0) : "r"(x1),"r"(x2),"r"(x3),"r"(x4),"r"(x5),"r"(x8) : "memory");
    return x0;
}
static slong sys_open(const char *p){return sc(SYS_openat,AT_FDCWD,(slong)p,O_RDWR|O_NONBLOCK,0,0,0);}
static slong sys_write(slong fd,const void *p,usize n){return sc(SYS_write,fd,(slong)p,n,0,0,0);}
static slong sys_read(slong fd,void *p,usize n){return sc(SYS_read,fd,(slong)p,n,0,0,0);}
static slong sys_ioctl(slong fd,usize request,void *ptr){return sc(SYS_ioctl,fd,request,(slong)ptr,0,0,0);}
static void sys_close(slong fd){sc(SYS_close,fd,0,0,0,0,0);}
static usize str_len(const char *s){usize n=0; while(s[n])n++;return n;}
static void print(const char *s){sys_write(1,s,str_len(s));}
static void num(slong x){ char b[32];int i=0;if(x<0){print("-");x=-x;}do{b[i++]='0'+(x%10);x/=10;}while(x && i<30);while(i--)sys_write(1,&b[i],1); }
static slong now(){struct timespec t;return sc(SYS_clock_gettime,CLOCK_MONOTONIC,(slong)&t,0,0,0,0)<0?0:t.sec;}
static int str_eq(const char*a,const char*b){while(*a && *b && *a==*b){a++;b++;}return *a==*b;}
static int duration(const char*s){int n=0;if(!s)return 30;for(int i=0;s[i];i++){if(s[i]<'0'||s[i]>'9')return -1;n=n*10+(s[i]-'0');if(n>86400)return -1;}return n;}
static int emit_axis(slong fd,u16 code,s32 val){
    struct input_event ev[2]={ {0,0,EV_ABS,code,val},{0,0,EV_SYN,0,0} };
    slong r=sys_write(fd,ev,sizeof(ev));
    if(r!=(slong)sizeof(ev)){print("ERROR: axis write failed code=");num(code);print(" ret=");num(r);print("\n");return -1;}
    return 0;
}
static int key_pressed(const u8 *bits,int code){return (bits[code/8] >> (code%8)) & 1;}
static void transition(slong fd,int left,int down,int *state,slong *writes,slong *errors,int trace){
    if(*state==down)return;
    *state=down;
    if(emit_axis(fd,left?ABS_BRAKE:ABS_GAS,down?32767:0)==0)(*writes)++;else (*errors)++;
    if(trace){print(left?"L2_AXIS ":"R2_AXIS ");num(down?32767:0);print("\n");}
}
__attribute__((used)) int entry(slong *sp){
    slong argc=sp[0]; const char**argv=(const char**)(sp+1);
    if(sizeof(struct input_event)!=24){print("ERROR: unexpected input_event size\n");return 4;}
    if(argc<2){print("Usage: nova_m1m2_native_v3 /dev/input/eventN [seconds|0] [trace|quiet]\n");return 2;}
    int seconds=duration(argc>=3?argv[2]:"30");
    if(seconds<0){print("ERROR: invalid seconds\n");return 2;}
    int trace=argc>=4 && str_eq(argv[3],"trace");
    slong fd=sys_open(argv[1]);
    if(fd<0){print("ERROR: cannot open evdev: errno=");num(-fd);print("\n");return 3;}
    print("NATIVE_V3_STARTED node=");print(argv[1]);print(" duration=");num(seconds);print(" trace=");num(trace);print("\n");
    slong end=seconds?now()+seconds:0;
    slong reads=0,evkey=0,m1key=0,m2key=0,m1poll=0,m2poll=0,leftwrites=0,rightwrites=0,errors=0;
    slong ioctlOK=0,ioctlERR=0;
    int leftState=0,rightState=0,lastPollL=-1,lastPollR=-1;
    int eventModeL=0,eventModeR=0;
    int result=0;
    while(!end || now()<end){
        /* Query actual held-button state even if event-stream delivery differs. */
        u8 bits[64]={0};
        slong k=sys_ioctl(fd,EVIOCGKEY64,bits);
        if(k>=0){
            ioctlOK++;
            int l=key_pressed(bits,M1_PHYSICAL),r=key_pressed(bits,M2_PHYSICAL);
            if(lastPollL!=l){if(lastPollL>=0){m1poll++;if(trace)print(l?"M1_IOCTL_DOWN\n":"M1_IOCTL_UP\n");}lastPollL=l;}
            if(lastPollR!=r){if(lastPollR>=0){m2poll++;if(trace)print(r?"M2_IOCTL_DOWN\n":"M2_IOCTL_UP\n");}lastPollR=r;}
            if(!eventModeL)transition(fd,1,l,&leftState,&leftwrites,&errors,trace);
            if(!eventModeR)transition(fd,0,r,&rightState,&rightwrites,&errors,trace);
        } else {
            ioctlERR++;
            if(ioctlERR==1){print("WARN: EVIOCGKEY unavailable errno=");num(-k);print("\n");}
        }
        /* Read kernel evdev events, including all key codes for troubleshooting. */
        struct pollfd p={(s32)fd,POLLIN,0};struct timespec t={0,20000000};
        slong ret=sc(SYS_ppoll,(slong)&p,1,(slong)&t,0,0,0);
        if(ret<0){if(ret==-4)continue;print("ERROR: ppoll ret=");num(ret);print("\n");result=5;break;}
        if(!ret)continue;
        if(p.revents&(POLLHUP|POLLERR)){print("WARN: controller disconnected\n");result=6;break;}
        if(!(p.revents&POLLIN))continue;
        struct input_event buf[64];slong r=sys_read(fd,buf,sizeof(buf));
        if(r==0){print("WARN: input EOF\n");result=6;break;}
        if(r<0){if(r==-11 || r==-4)continue;print("ERROR: read failure ret=");num(r);print("\n");result=6;break;}
        if(r%(slong)sizeof(struct input_event)){print("ERROR: partial event read\n");result=5;break;}
        reads+=r/(slong)sizeof(struct input_event);
        for(slong i=0;i<r/(slong)sizeof(struct input_event);i++){
            struct input_event *e=&buf[i];
            if(e->type!=EV_KEY)continue;
            evkey++;
            if(trace && evkey<=100){print("RAW_KEY code=");num(e->code);print(" value=");num(e->value);print("\n");}
            int left=e->code==M1_PHYSICAL,right=e->code==M2_PHYSICAL;
            if(!left && !right)continue;
            if(left)m1key++;else m2key++;
            if(trace){print(left?"M1_KEY ":"M2_KEY ");num(e->value);print("\n");}
            if(e->value!=0 && e->value!=1)continue;
            /* Prefer actual key events if delivered. Polling is fallback for
             * unusual virtual devices which expose held state but not events. */
            if(left){eventModeL=1;transition(fd,1,e->value,&leftState,&leftwrites,&errors,trace);}
            else {eventModeR=1;transition(fd,0,e->value,&rightState,&rightwrites,&errors,trace);}
        }
        if(errors>10){result=7;break;}
    }
    if(emit_axis(fd,ABS_BRAKE,0))errors++;
    if(emit_axis(fd,ABS_GAS,0))errors++;
    print("NATIVE_V3_FINISHED reads=");num(reads);
    print(" evkey=");num(evkey);
    print(" M1key=");num(m1key);
    print(" M2key=");num(m2key);
    print(" M1poll=");num(m1poll);
    print(" M2poll=");num(m2poll);
    print(" L2writes=");num(leftwrites);
    print(" R2writes=");num(rightwrites);
    print(" ioctlOK=");num(ioctlOK);
    print(" ioctlERR=");num(ioctlERR);
    print(" errors=");num(errors);print("\n");
    sys_close(fd);return result?result:(errors?7:0);
}
__asm__(".global _start\n_start:\n mov x0, sp\n bl entry\n mov x8, #93\n svc #0\n");
