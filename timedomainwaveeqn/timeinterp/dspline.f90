MODULE dspline

IMPLICIT NONE

! Use predictor-corrector schemes based on difference splines 

CONTAINS


  SUBROUTINE point_to_Taylor(x,y,c,x0,m)
!
! Compute the coefficients in Taylor form centered at x0
! of the interpolant of the data y at the nodes x
!
  INTEGER, INTENT(IN) :: m  ! The degree
  DOUBLE PRECISION, DIMENSION(0:m), INTENT(IN) :: x,y
  DOUBLE PRECISION, DIMENSION(0:m), INTENT(OUT) :: c
  DOUBLE PRECISION, INTENT(IN) :: x0
!
  DOUBLE PRECISION, DIMENSION(0:m) :: dx,newton
  INTEGER :: j,k
!
! Compute the Newton polynomial
!
  dx=x-x0
  newton=y
  DO k=1,m
    DO j=0,m-k
      newton(j)=(newton(j+1)-newton(j))/(dx(j+k)-dx(j))
    END DO
  END DO
!
! Now change from Newton to Taylor
!
  c=0.d0
  c(0)=newton(0)
  DO k=1,m
    DO j=k,1,-1
      c(j)=c(j-1)-dx(k)*c(j)
    END DO
    c(0)=newton(k)-dx(k)*c(0)
  END DO
!
  END SUBROUTINE point_to_Taylor

  SUBROUTINE Hermite(cl,xl,cr,xr,ch,x0,m)
!
! Compute the Hermite interpolant of the degree m Taylor polynomials
! centered at xl,xr and express as a degree 2m+1 Taylor polynomial
! centered at x0 
!
  INTEGER, INTENT(IN) :: m
  DOUBLE PRECISION, INTENT(IN) :: xl,xr,x0
  DOUBLE PRECISION, DIMENSION(0:m), INTENT(IN) :: cl,cr
  DOUBLE PRECISION, DIMENSION(0:2*m+1), INTENT(OUT) :: ch 
!
  DOUBLE PRECISION, DIMENSION(0:2*m+1) :: dx,Newton
  INTEGER :: j,k
!
  dx(0:m)=xl-x0
  dx(m+1:2*m+1)=xr-x0
  Newton(0:m)=cl(0)
  Newton(m+1:2*m+1)=cr(0)
!
  DO k=1,2*m+1
    IF (k <= m) THEN
      DO j=0,m-k
        Newton(j)=cl(k)
      END DO
      DO j=m-k+1,m
        Newton(j)=(Newton(j+1)-Newton(j))/(dx(j+k)-dx(j))
      END DO
      DO j=m+1,2*m+1-k
        Newton(j)=cr(k)
      END DO
    ELSE
      DO j=0,2*m+1-k
        Newton(j)=(Newton(j+1)-Newton(j))/(dx(j+k)-dx(j))
      END DO
    END IF
  END DO
!
! Now change from Newton to Taylor
!
  ch=0.d0
  ch(0)=Newton(0)
  DO k=1,2*m+1
    DO j=k,1,-1
      ch(j)=ch(j-1)-dx(k)*ch(j)
    END DO
    ch(0)=Newton(k)-dx(k)*ch(0)
  END DO
!
  END SUBROUTINE Hermite 

!
  SUBROUTINE point_to_dspline(x,y,c,xl,xr,m,n)
!
! Compute the coefficients of the degree 2m+1 dspline on [xl,xr]
!
! The result is in Taylor form centered at (xl+xr)/2 
!
! Assume data for xl starts at x(0) and for xr ends at x(n)
!
  INTEGER, INTENT(IN) :: m,n
  DOUBLE PRECISION, DIMENSION(0:n), INTENT(IN) :: x,y
  DOUBLE PRECISION, DIMENSION(0:2*m+1), INTENT(OUT) :: c
  DOUBLE PRECISION, INTENT(IN) :: xl,xr
!
  DOUBLE PRECISION, DIMENSION(0:m) :: yl,xxl,yr,xxr,cl,cr
  DOUBLE PRECISION :: x0
  INTEGER :: j
!
! Check for enough data
!
  IF (n < m) THEN 
    PRINT *,'Not enough data in point_to_dspline'
    STOP
  END IF
!
  yl=y(0:m)
  xxl=x(0:m)
  yr=y(n-m:n)
  xxr=x(n-m:n)
  x0=(xl+xr)/2.d0 
!
  CALL point_to_Taylor(xxl,yl,cl,xl,m)
  CALL point_to_Taylor(xxr,yr,cr,xr,m)
  CALL Hermite(cl,xl,cr,xr,c,x0,m)    
!
  END SUBROUTINE point_to_dspline 

  SUBROUTINE Interp(tnow,t,dt,uev,upev,u,m,n)
!
  INTEGER, INTENT(IN) :: m,n
  DOUBLE PRECISION, INTENT(IN) :: tnow,t,dt
  DOUBLE PRECISION, DIMENSION(n), INTENT(IN) :: u
  DOUBLE PRECISION, INTENT(OUT) :: uev,upev
!
! tnow - current time
! t    - desired time <= tnow
! dt   - time step
! u    - data u(j)=u at time tnow-(n-j)*dt
! n    - dimension of u Must have t >= tnow-(n-2)*dt
! m    - degree 2m+1 spline   
! uev,upev - dspline interpolant and derivative evaluated at t
!
  INTEGER :: k,nh,jr,nr
  DOUBLE PRECISION, DIMENSION(:), ALLOCATABLE :: x,y
  DOUBLE PRECISION, DIMENSION(0:2*m+1) :: c
  DOUBLE PRECISION :: tl,tr,s  
!
! Where is t?
!
  jr=INT((tnow-t)/dt)
  tr=tnow-dt*DBLE(jr)
  tl=tr-dt 
  s=t-.5d0*(tl+tr) 
!
! t is located between n-jr-1 and n-jr 
!
! Are we in a regular case or near the present time?
!
  IF ((n-jr+m/2) <= n) THEN
    nh=m+1
    nr=n-jr+m/2
  ELSE
    nh=m
    nr=n
  END IF
  ALLOCATE(x(0:nh),y(0:nh))
  IF ((nr-nh) < 0) THEN
    y(nh-nr:nh)=u(0:nr)
    y(0:nh-nr-1)=0.d0
  ELSE
    y(0:nh)=u(nr-nh:nr)
  END IF
  DO k=0,nh
    x(k)=tnow-dt*DBLE(n-nr+nh-k)
  END DO 
  CALL point_to_dspline(x,y,c,tl,tr,m,nh)
  uev=c(2*m+1)
  upev=DBLE(2*m+1)*c(2*m+1)
  DO k=2*m,1,-1 
    uev=s*uev+c(k)
    upev=s*upev+DBLE(k)*c(k)
  END DO
  uev=s*uev+c(0)
!
  DEALLOCATE(x,y)
!
  END SUBROUTINE Interp 

  SUBROUTINE Extrap(xcof,m)
!
  INTEGER, INTENT(IN) :: m
  DOUBLE PRECISION, DIMENSION(0:m), INTENT(OUT) :: xcof
!
! Return extrapolation coefficients for degree m
!
  INTEGER :: k,j
!
  DO k=0,m
    xcof(k)=1.d0
    DO j=0,m
      IF (j /= k) THEN
        xcof(k)=xcof(k)*DBLE(m+1-j)/DBLE(k-j)
      END IF
    END DO
  END DO 
!
  END SUBROUTINE Extrap  

  SUBROUTINE Extrapnoalloc(xcof,m)
! Barnett needed version that doesn't allocate, to call from matlab/mex
! 12/22/16
  INTEGER, INTENT(IN) :: m
  DOUBLE PRECISION, DIMENSION(0:m), INTENT(INOUT) :: xcof
!
! Return extrapolation coefficients for degree m
!
  INTEGER :: k,j
!
  DO k=0,m
    xcof(k)=1.d0
    DO j=0,m
      IF (j /= k) THEN
        xcof(k)=xcof(k)*DBLE(m+1-j)/DBLE(k-j)
      END IF
    END DO
  END DO 
!
  END SUBROUTINE Extrapnoalloc

  SUBROUTINE InterpMat(r,tinterp,dt,m,jmax,jmin,umat,upmat)
!
  INTEGER, INTENT(IN) :: m,r
  DOUBLE PRECISION, DIMENSION(r), INTENT(IN) :: tinterp
  DOUBLE PRECISION, INTENT(IN) :: dt 
  INTEGER, INTENT(OUT) :: jmax,jmin 
  DOUBLE PRECISION, DIMENSION(:,:), ALLOCATABLE, INTENT(OUT) :: umat,upmat 
!
! r       - number of interpolation times 
! tinterp - desired times assumed negative with the current time =0 
! dt      - time step
! m       - degree 2m+1 spline   
! jmax    - maximum time index for interpolation data - <= 0 with current time 0 
! jmin    - minimum time index for interpolation data - <= 0 with current time 0
! umat    - matrix of dimension r X (jmax-jmin+1) for u interpolation
! upmat   - matrix of dimension r X (jmax-jmin+1) for du/dt interpolation
!
  INTEGER :: jt,mh,j,k,jf,nr,kp,nc
  DOUBLE PRECISION, DIMENSION(:,:), ALLOCATABLE :: u_to_cof
  DOUBLE PRECISION, DIMENSION(:,:,:), ALLOCATABLE :: uf_to_cof
  DOUBLE PRECISION, DIMENSION(0:2*m+1) :: c
  DOUBLE PRECISION, DIMENSION(0:m+1) :: x,y
  DOUBLE PRECISION, DIMENSION(0:m) :: xf,yf
  INTEGER, DIMENSION(r) :: jtmax,jtmin 
  DOUBLE PRECISION :: tl,tr,s  
!  LOGICAL, SAVE :: first_call=.TRUE.
!
  mh=m/2
!
    ALLOCATE(u_to_cof(0:2*m+1,m+2)) 
    DO k=0,m+1
      x(k)=dt*DBLE(k-mh) 
    END DO 
    tl=x(mh)
    tr=x(mh+1)
    DO k=0,m+1
      y=0.d0
      y(k)=1.d0
      CALL point_to_dspline(x,y,c,tl,tr,m,m+1)
      DO j=0,2*m+1
        u_to_cof(j,k+1)=c(j)
      END DO 
    END DO
!
    ALLOCATE(uf_to_cof(mh,0:2*m+1,m+1))
    DO k=0,m
      xf(k)=dt*DBLE(k-m) 
    END DO 
    DO jf=1,mh
      tr=dt*DBLE(jf-mh)
      tl=tr-dt 
      DO k=0,m
        yf=0.d0
        yf(k)=1.d0
        CALL point_to_dspline(xf,yf,c,tl,tr,m,m)
        DO j=0,2*m+1
          uf_to_cof(jf,j,k+1)=c(j)
        END DO 
      END DO
    END DO
!
  
  DO jt=1,r 
!
! Where is t?
!
    nr=INT(tinterp(jt)/dt)
    jtmax(jt)=MIN(0,nr+mh)
    jtmin(jt)=MIN(-m,nr-1-mh)
    IF (jt==1) THEN
      jmax=jtmax(1)
      jmin=jtmin(1)
    END IF
    IF (jtmax(jt) > jmax) THEN
      jmax=jtmax(jt)
    END IF
    IF (jtmin(jt) < jmin) THEN
      jmin=jtmin(jt)
    END IF 
!
  END DO 
!
  nc=jmax-jmin+1
  ALLOCATE(umat(r,nc),upmat(r,nc))
  umat=0.d0
  upmat=0.d0 
!
  DO jt=1,r
    s=tinterp(jt)-dt*(DBLE(INT(tinterp(jt)/dt))-.5d0)
    IF ((jtmax(jt)-jtmin(jt))==(m+1)) THEN
      DO k=1,m+2
        kp=jtmin(jt)-jmin+k
        umat(jt,kp)=u_to_cof(2*m+1,k)
        upmat(jt,kp)=DBLE(2*m+1)*u_to_cof(2*m+1,k)
        DO j=2*m,1,-1 
          umat(jt,kp)=s*umat(jt,kp)+u_to_cof(j,k)
          upmat(jt,kp)=s*upmat(jt,kp)+DBLE(j)*u_to_cof(j,k)
        END DO
        umat(jt,kp)=s*umat(jt,kp)+u_to_cof(0,k)
      END DO
    ELSE
      jf=INT(tinterp(jt)/dt)+mh 
      DO k=1,m+1
        kp=jtmin(jt)-jmin+k
        umat(jt,kp)=uf_to_cof(jf,2*m+1,k)
        upmat(jt,kp)=DBLE(2*m+1)*uf_to_cof(jf,2*m+1,k)
        DO j=2*m,1,-1 
          umat(jt,kp)=s*umat(jt,kp)+uf_to_cof(jf,j,k)
          upmat(jt,kp)=s*upmat(jt,kp)+DBLE(j)*uf_to_cof(jf,j,k)
        END DO
        umat(jt,kp)=s*umat(jt,kp)+uf_to_cof(jf,0,k)
      END DO
    END IF
!
  END DO
!
  END SUBROUTINE InterpMat

! Barnett/MEX needed this f77-style version which assumes outputs allocated:
  SUBROUTINE InterpMatnoalloc(r,tinterp,dt,m,jmax,jmin,umat,upmat,nc)
!
  INTEGER, INTENT(IN) :: m,r,nc
  DOUBLE PRECISION, DIMENSION(r), INTENT(IN) :: tinterp
  DOUBLE PRECISION, INTENT(IN) :: dt 
  INTEGER, INTENT(OUT) :: jmax,jmin 
  DOUBLE PRECISION, DIMENSION(r,nc), INTENT(INOUT) :: umat,upmat 
!
! r       - number of interpolation times 
! tinterp - desired times assumed negative with the current time =0 
! dt      - time step
! m       - degree 2m+1 spline   
! jmax    - maximum time index for interpolation data - <= 0 with current time 0 
! jmin    - minimum time index for interpolation data - <= 0 with current time 0
! umat    - matrix of dimension r X (jmax-jmin+1) for u interpolation
! upmat   - matrix of dimension r X (jmax-jmin+1) for du/dt interpolation
!
  INTEGER :: jt,mh,j,k,jf,nr,kp
  DOUBLE PRECISION, DIMENSION(:,:), ALLOCATABLE :: u_to_cof
  DOUBLE PRECISION, DIMENSION(:,:,:), ALLOCATABLE :: uf_to_cof
  DOUBLE PRECISION, DIMENSION(0:2*m+1) :: c
  DOUBLE PRECISION, DIMENSION(0:m+1) :: x,y
  DOUBLE PRECISION, DIMENSION(0:m) :: xf,yf
  INTEGER, DIMENSION(r) :: jtmax,jtmin 
  DOUBLE PRECISION :: tl,tr,s  
!  LOGICAL, SAVE :: first_call=.TRUE.
!
  mh=m/2
!
    ALLOCATE(u_to_cof(0:2*m+1,m+2)) 
    DO k=0,m+1
      x(k)=dt*DBLE(k-mh) 
    END DO 
    tl=x(mh)
    tr=x(mh+1)
    DO k=0,m+1
      y=0.d0
      y(k)=1.d0
      CALL point_to_dspline(x,y,c,tl,tr,m,m+1)
      DO j=0,2*m+1
        u_to_cof(j,k+1)=c(j)
      END DO 
    END DO
!
    ALLOCATE(uf_to_cof(mh,0:2*m+1,m+1))
    DO k=0,m
      xf(k)=dt*DBLE(k-m) 
    END DO 
    DO jf=1,mh
      tr=dt*DBLE(jf-mh)
      tl=tr-dt 
      DO k=0,m
        yf=0.d0
        yf(k)=1.d0
        CALL point_to_dspline(xf,yf,c,tl,tr,m,m)
        DO j=0,2*m+1
          uf_to_cof(jf,j,k+1)=c(j)
        END DO 
      END DO
    END DO
!
  
  DO jt=1,r 
!
! Where is t?
!
    nr=INT(tinterp(jt)/dt)
    jtmax(jt)=MIN(0,nr+mh)
    jtmin(jt)=MIN(-m,nr-1-mh)
    IF (jt==1) THEN
      jmax=jtmax(1)
      jmin=jtmin(1)
    END IF
    IF (jtmax(jt) > jmax) THEN
      jmax=jtmax(jt)
    END IF
    IF (jtmin(jt) < jmin) THEN
      jmin=jtmin(jt)
    END IF 
!
  END DO 
!
!  nc=jmax-jmin+1
!  ALLOCATE(umat(r,nc),upmat(r,nc))
  umat=0.d0
  upmat=0.d0 
!
  DO jt=1,r
    s=tinterp(jt)-dt*(DBLE(INT(tinterp(jt)/dt))-.5d0)
    IF ((jtmax(jt)-jtmin(jt))==(m+1)) THEN
      DO k=1,m+2
        kp=jtmin(jt)-jmin+k
        umat(jt,kp)=u_to_cof(2*m+1,k)
        upmat(jt,kp)=DBLE(2*m+1)*u_to_cof(2*m+1,k)
        DO j=2*m,1,-1 
          umat(jt,kp)=s*umat(jt,kp)+u_to_cof(j,k)
          upmat(jt,kp)=s*upmat(jt,kp)+DBLE(j)*u_to_cof(j,k)
        END DO
        umat(jt,kp)=s*umat(jt,kp)+u_to_cof(0,k)
      END DO
    ELSE
      jf=INT(tinterp(jt)/dt)+mh 
      DO k=1,m+1
        kp=jtmin(jt)-jmin+k
        umat(jt,kp)=uf_to_cof(jf,2*m+1,k)
        upmat(jt,kp)=DBLE(2*m+1)*uf_to_cof(jf,2*m+1,k)
        DO j=2*m,1,-1 
          umat(jt,kp)=s*umat(jt,kp)+uf_to_cof(jf,j,k)
          upmat(jt,kp)=s*upmat(jt,kp)+DBLE(j)*uf_to_cof(jf,j,k)
        END DO
        umat(jt,kp)=s*umat(jt,kp)+uf_to_cof(jf,0,k)
      END DO
    END IF
!
  END DO
!
  END SUBROUTINE InterpMatnoalloc 

END MODULE dspline 
 
      
  
