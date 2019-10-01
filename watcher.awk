BEGIN{
 x="";
 y="";
 ts="";
}
{

if ( NR == 1 )
 {
  x=systime();
  ts=x;
 }
else
 {
   y=systime()-x;
   x=systime();
   if ( y > dt ) { ts=x; }
 }

printf "%d:%s\n", ts, $0;
}
