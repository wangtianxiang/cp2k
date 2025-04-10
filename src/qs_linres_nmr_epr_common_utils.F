!--------------------------------------------------------------------------------------------------!
!   CP2K: A general program to perform molecular dynamics simulations                              !
!   Copyright 2000-2025 CP2K developers group <https://cp2k.org>                                   !
!                                                                                                  !
!   SPDX-License-Identifier: GPL-2.0-or-later                                                      !
!--------------------------------------------------------------------------------------------------!

! **************************************************************************************************
!> \brief given the response wavefunctions obtained by the application
!>      of the (rxp), p, and ((dk-dl)xp) operators,
!>      here the current density vector (jx, jy, jz)
!>      is computed for the 3 directions of the magnetic field (Bx, By, Bz)
!> \par History
!>      created 02-2006 [MI]
!> \author MI
! **************************************************************************************************
MODULE qs_linres_nmr_epr_common_utils
   USE kinds,                           ONLY: dp
   USE mathconstants,                   ONLY: gaussi
   USE pw_grid_types,                   ONLY: pw_grid_type
   USE pw_methods,                      ONLY: pw_transfer
   USE pw_pool_types,                   ONLY: pw_pool_type
   USE pw_types,                        ONLY: pw_c1d_gs_type
#include "./base/base_uses.f90"

   IMPLICIT NONE

   PRIVATE

   ! *** Public subroutines ***
   PUBLIC :: mult_G_ov_G2_grid

   CHARACTER(len=*), PARAMETER, PRIVATE :: moduleN = 'qs_linres_nmr_epr_common_utils'

CONTAINS

! **************************************************************************************************
!> \brief Given the current density on the PW grid in reciprcal space
!>       (obtained by FFT), calculate the integral
!>         \int_{r}[ ((r-r') x j(r))/|r-r'|^3 ] = Bind(r')
!>       which in reciprcal space reads  (for G/=0)
!>          i G/|G|^2 x J(G)
!> \param pw_pool ...
!> \param rho_gspace ...
!> \param funcG_times_rho ...
!> \param idir ...
!> \param my_chi ...
!> \author MI
!> \note
!>      The G=0 component is not comnputed here, but can be evaluated
!>      through the susceptibility and added to the shift in a second time
!>
!>      This method would not work for a non periodic system
!>      It should be generalized like the calculation of Hartree
! **************************************************************************************************
   SUBROUTINE mult_G_ov_G2_grid(pw_pool, rho_gspace, funcG_times_rho, idir, my_chi)

      TYPE(pw_pool_type), POINTER                        :: pw_pool
      TYPE(pw_c1d_gs_type), INTENT(IN)                   :: rho_gspace
      TYPE(pw_c1d_gs_type), INTENT(INOUT)                :: funcG_times_rho
      INTEGER, INTENT(IN)                                :: idir
      REAL(dp), INTENT(IN)                               :: my_chi

      INTEGER                                            :: handle, ig, ng
      REAL(dp)                                           :: g2
      TYPE(pw_c1d_gs_type)                               :: influence_fn
      TYPE(pw_grid_type), POINTER                        :: grid
      CHARACTER(len=*), PARAMETER                        :: routineN = 'mult_G_ov_G2_grid'

      CALL timeset(routineN, handle)

      CALL pw_pool%create_pw(influence_fn)

      grid => influence_fn%pw_grid
      DO ig = grid%first_gne0, grid%ngpts_cut_local
         g2 = grid%gsq(ig)
         influence_fn%array(ig) = gaussi*grid%g(idir, ig)/g2
      END DO ! ig
      IF (grid%have_g0) influence_fn%array(1) = 0.0_dp

      CALL pw_transfer(rho_gspace, funcG_times_rho)

      ng = SIZE(grid%gsq)
      funcG_times_rho%array(1:ng) = funcG_times_rho%array(1:ng)*influence_fn%array(1:ng)
      IF (grid%have_g0) funcG_times_rho%array(1) = my_chi

      CALL pw_pool%give_back_pw(influence_fn)

      CALL timestop(handle)

   END SUBROUTINE mult_G_ov_G2_grid

END MODULE qs_linres_nmr_epr_common_utils
