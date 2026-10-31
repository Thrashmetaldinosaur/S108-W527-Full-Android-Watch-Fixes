/* S108 V28 experimental root-side power-key injection. Device-tested
 * October 30 2026: Linux KEY_POWER (116) sleeps this Android 13 S108.
 * No Binder service; no accelerometer/IRQ access or kernel modifications.
 * Build for AArch64 as a static freestanding binary and verify its hash.
 */
typedef unsigned short u16;
typedef unsigned int u32;
typedef long long s64;
typedef unsigned long ul;
#define NR_openat 56
#define NR_close 57
#define NR_write 64
#define NR_ioctl 29
#define NR_nanosleep 101
#define NR_exit_group 94
#define AT_FDCWD -100
#define O_WRONLY 1
#define O_NONBLOCK 04000
static long call1(long n,long a){register long x8 __asm__("x8")=n;register long x0 __asm__("x0")=a;__asm__ volatile("svc #0":"+r"(x0):"r"(x8):"memory");return x0;}
static long call2(long n,long a,long b){register long x8 __asm__("x8")=n;register long x0 __asm__("x0")=a;register long x1 __asm__("x1")=b;__asm__ volatile("svc #0":"+r"(x0):"r"(x1),"r"(x8):"memory");return x0;}
static long call3(long n,long a,long b,long c){register long x8 __asm__("x8")=n;register long x0 __asm__("x0")=a;register long x1 __asm__("x1")=b;register long x2 __asm__("x2")=c;__asm__ volatile("svc #0":"+r"(x0):"r"(x1),"r"(x2),"r"(x8):"memory");return x0;}
static void out(const char *s){ul n=0;while(s[n])n++;call3(NR_write,1,(long)s,n);}
static void zero(void *p,ul n){char *q=(char*)p;while(n--)*q++=0;}
static void copy(char *dst,const char *src,ul max){ul i=0;while(i<max&&src[i]){dst[i]=src[i];i++;}}
static void ms(long m){struct{s64 sec,nsec;}t={m/1000,(m%1000)*1000000};call2(NR_nanosleep,(long)&t,0);}
static void done(long x){call1(NR_exit_group,x);for(;;){}}
struct devid{u16 bus,vendor,product,version;};
struct uinput_user_dev{char name[80];struct devid id;u32 ff_effects_max;int absmax[64],absmin[64],absfuzz[64],absflat[64];};
struct input_event{s64 sec,usec;u16 type,code;int value;};
static int emit(long fd,u16 typ,u16 code,int val){struct input_event e;zero(&e,sizeof(e));e.type=typ;e.code=code;e.value=val;return call3(NR_write,fd,(long)&e,sizeof(e))==sizeof(e);}
void _start(void){
 long fd=call3(NR_openat,AT_FDCWD,(long)"/dev/uinput",O_WRONLY|O_NONBLOCK);
 if(fd<0){out("UINPUT_OPEN_FAILED\n");done(21);}
 if(call3(NR_ioctl,fd,0x40045564,1)<0 || call3(NR_ioctl,fd,0x40045565,116)<0){out("UINPUT_IOCTL_FAILED\n");call1(NR_close,fd);done(22);}
 struct uinput_user_dev d;zero(&d,sizeof(d));copy(d.name,"S108_V28_POWER_KEY_TEST",sizeof(d.name));d.id.bus=0x18;d.id.vendor=0x0108;d.id.product=0x2828;d.id.version=1;
 if(call3(NR_write,fd,(long)&d,sizeof(d))!=sizeof(d)){out("UINPUT_SETUP_FAILED\n");call1(NR_close,fd);done(23);}
 if(call2(NR_ioctl,fd,0x5501)<0){out("UINPUT_CREATE_FAILED\n");call1(NR_close,fd);done(24);}
 out("UINPUT_DEVICE_READY\n");ms(1150);
 int ok=emit(fd,1,116,1);ok&=emit(fd,0,0,0);ms(85);ok&=emit(fd,1,116,0);ok&=emit(fd,0,0,0);
 if(ok)out("POWER_KEY_EMITTED\n");else out("POWER_KEY_WRITE_FAILED\n");
 ms(420);call2(NR_ioctl,fd,0x5502);call1(NR_close,fd);
 if(!ok)done(25);done(0);
}
