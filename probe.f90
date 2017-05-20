!==================================================
! Subroutine for sampling the velocity from a point
! 
!==================================================

! Routine that initializes the probe locations
subroutine init_probe

use param
use variables
use var

    implicit none
    character(1000) :: ReadLine
    integer :: i

    open(70,file=Probelistfile) 
    ! Read the Number of Blades
    read(15,'(A)') ReadLine
    read(ReadLine(index(ReadLine,':')+1:),*) Nprobes 

    ! Allocate the probe locations
    allocate(xprobe(Nprobes),yprobe(Nprobes),zprobe(Nprobes),uprobe(Nprobes),vprobe(Nprobes),wprobe(Nprobes))
    allocate(uprobe_part(Nprobes),vprobe_part(Nprobes),wprobe_part(Nprobes))

    do i=1,Nprobes
    
    read(15,'(A)') ReadLine ! Probe point ... 

    read(ReadLine,*) xprobe(i), yprobe(i), zprobe(i)

    end do

end subroutine init_probe

subroutine probe(ux,uy,uz,phi) 
    
use actuator_line_model_utils ! used only for the trilinear interpolation
USE param 
USE decomp_2d
USE variables
use var
use MPI

implicit none

real(mytype), dimension(xsize(1),xsize(2),xsize(3)) :: ux,uy,uz,phi
integer :: i,j,k, ipr, ierr
real(mytype) :: ymin,ymax,zmin,zmax
real(mytype) :: xmesh,ymesh,zmesh
real(mytype) :: dist, min_dist 
real(mytype) :: x0,y0,z0,x1,y1,z1,x,y,z,u000,u100,u001,u101,u010,u110,u011,u111
integer :: min_i,min_j,min_k
integer :: i_lower, j_lower, k_lower, i_upper, j_upper, k_upper
        
        if (istret.eq.0) then 
        ymin=(xstart(2)-1)*dy
        ymax=xend(2)*dy
        else
        ymin=yp(xstart(2))
        ymax=yp(xend(2))
        endif

        zmin=(xstart(3)-1)*dz
        zmax=(xend(3)-1)*dz
         
        do ipr=1,Nprobes
        
        min_dist=1e6
        if((yprobe(ipr)>=ymin).and.(yprobe(ipr)<=ymax).and.(zprobe(ipr)>=zmin).and.(zprobe(ipr)<=zmax)) then
            !write(*,*) 'Warning: I own this node'
            do k=xstart(3),xend(3)
            zmesh=(k-1)*dz 
            do j=xstart(2),xend(2)
            if (istret.eq.0) ymesh=(j-1)*dy
            if (istret.ne.0) ymesh=yp(j)
            do i=xstart(1),xend(1)
            xmesh=(i-1)*dx
            dist = sqrt((xprobe(ipr)-xmesh)**2+(yprobe(ipr)-ymesh)**2+(zprobe(ipr)-zmesh)**2) 
            
            if (dist<min_dist) then
                min_dist=dist
                min_i=i
                min_j=j
                min_k=k
            endif

            enddo
            enddo
            enddo
            
            if(yprobe(ipr)>ymax.or.yprobe(ipr)<ymin) then
            write(*,*) 'In processor ', nrank
            write(*,*) 'yprobe =', yprobe(ipr),'is not within the', ymin, ymax, 'limits'
            stop
            endif 

            if(xprobe(ipr)>(min_i-1)*dx) then
                i_lower=min_i
                i_upper=min_i+1
            else if(xprobe(ipr)<(min_i-1)*dx) then
                i_lower=min_i-1
                i_upper=min_i
            else if(xprobe(ipr)==(min_i-1)*dx) then
                i_lower=min_i
                i_upper=min_i
            endif
             
            if (istret.eq.0) then 
            if(yprobe(ipr)>(min_j-1)*dy) then
                j_lower=min_j
                j_upper=min_j+1
            else if(yprobe(ipr)<(min_j-1)*dy) then
                j_lower=min_j-1
                j_upper=min_j
            else if (yprobe(ipr)==(min_j-1)*dy) then
                j_lower=min_j
                j_upper=min_j
            endif
            else
            
            if(yprobe(ipr)>yp(min_j)) then
                j_lower=min_j
                j_upper=min_j+1
            else if(yprobe(ipr)<yp(min_j)) then
                j_lower=min_j-1
                j_upper=min_j
            else if (yprobe(ipr)==yp(min_j)) then
                j_lower=min_j
                j_upper=min_j
            endif
            endif
            
            if(zprobe(ipr)>(min_k-1)*dz) then
                k_lower=min_k
                k_upper=min_k+1
            else if(zprobe(ipr)<(min_k-1)*dz) then
                k_lower=min_k-1
                k_upper=min_k
            else if (zprobe(ipr)==(min_k-1)*dz) then
                k_lower=min_k
                k_upper=min_k
            endif

            ! Prepare for interpolation
            x0=(i_lower-1)*dx
            x1=(i_upper-1)*dx
            if (istret.eq.0) then
            y0=(j_lower-1)*dy
            y1=(j_upper-1)*dy
            else
            y0=yp(j_lower)
            y1=yp(j_upper)
            endif
            z0=(k_lower-1)*dz
            z1=(k_upper-1)*dz

            x=xprobe(ipr)
            y=yprobe(ipr)
            z=zprobe(ipr)
             
            if(x>x1.or.x<x0.or.y>y1.or.y<y0.or.z>z1.or.z<z0) then 
                write(*,*) 'x0, x1, x', x0, x1, x
                write(*,*) 'y0, y1, y', y0, y1, y
                write(*,*) 'z0, z1, z', z0, z1, z
                write(*,*) 'Problem with the trilinear interpolation'; 
                stop
            endif
            ! Apply interpolation kernels from 8 neighboring nodes    
            uprobe_part(ipr)= trilinear_interpolation(x0,y0,z0, &
                                                  x1,y1,z1, &
                                                  x,y,z, &
                                                  ux1(i_lower,j_lower,k_lower), &
                                                  ux1(i_upper,j_lower,k_lower), &
                                                  ux1(i_lower,j_lower,k_upper), &
                                                  ux1(i_upper,j_lower,k_upper), &
                                                  ux1(i_lower,j_upper,k_lower), &
                                                  ux1(i_upper,j_upper,k_lower), &
                                                  ux1(i_lower,j_upper,k_upper), &
                                                  ux1(i_upper,j_upper,k_upper))
            
              vprobe_part(ipr)= trilinear_interpolation(x0,y0,z0, &
                                                  x1,y1,z1, &
                                                  x,y,z, &
                                                  uy1(i_lower,j_lower,k_lower), &
                                                  uy1(i_upper,j_lower,k_lower), &
                                                  uy1(i_lower,j_lower,k_upper), &
                                                  uy1(i_upper,j_lower,k_upper), &
                                                  uy1(i_lower,j_upper,k_lower), &
                                                  uy1(i_upper,j_upper,k_lower), &
                                                  uy1(i_lower,j_upper,k_upper), &
                                                  uy1(i_upper,j_upper,k_upper))
          
              wprobe_part(ipr)= trilinear_interpolation(x0,y0,z0, &
                                                  x1,y1,z1, &
                                                  x,y,z, &
                                                  uz1(i_lower,j_lower,k_lower), &
                                                  uz1(i_upper,j_lower,k_lower), &
                                                  uz1(i_lower,j_lower,k_upper), &
                                                  uz1(i_upper,j_lower,k_upper), &
                                                  uz1(i_lower,j_upper,k_lower), &
                                                  uz1(i_upper,j_upper,k_lower), &
                                                  uz1(i_lower,j_upper,k_upper), &
                                                  uz1(i_upper,j_upper,k_upper))
 
        else
            uprobe_part(ipr)=0.0
            vprobe_part(ipr)=0.0
            wprobe_part(ipr)=0.0
            !write(*,*) 'Warning: I do not own this node' 
        endif
        enddo
           
        call MPI_ALLREDUCE(uprobe_part,uprobe,Nprobes,MPI_REAL8,MPI_SUM, &
            MPI_COMM_WORLD,ierr)
        call MPI_ALLREDUCE(vprobe_part,vprobe,Nprobes,MPI_REAL8,MPI_SUM, &
            MPI_COMM_WORLD,ierr)
        call MPI_ALLREDUCE(wprobe_part,wprobe,Nprobes,MPI_REAL8,MPI_SUM, &
            MPI_COMM_WORLD,ierr)

end subroutine probe
