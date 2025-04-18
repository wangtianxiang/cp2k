!--------------------------------------------------------------------------------------------------!
!   CP2K: A general program to perform molecular dynamics simulations                              !
!   Copyright 2000-2025 CP2K developers group <https://cp2k.org>                                   !
!                                                                                                  !
!   SPDX-License-Identifier: GPL-2.0-or-later                                                      !
!--------------------------------------------------------------------------------------------------!

! **************************************************************************************************
!> \brief Calculate MAO's and analyze wavefunctions
!> \par History
!>      03.2016 created [JGH]
!>      12.2016 split into four modules [JGH]
!> \author JGH
! **************************************************************************************************
MODULE mao_optimizer
   USE cp_dbcsr_api,                    ONLY: &
        dbcsr_add, dbcsr_copy, dbcsr_create, dbcsr_distribution_type, dbcsr_get_info, dbcsr_norm, &
        dbcsr_norm_maxabsnorm, dbcsr_p_type, dbcsr_release, dbcsr_reserve_diag_blocks, dbcsr_type, &
        dbcsr_type_symmetric
   USE cp_dbcsr_operations,             ONLY: dbcsr_allocate_matrix_set,&
                                              dbcsr_deallocate_matrix_set
   USE kinds,                           ONLY: dp
   USE mao_methods,                     ONLY: mao_function,&
                                              mao_function_gradient,&
                                              mao_initialization,&
                                              mao_orthogonalization,&
                                              mao_scalar_product
#include "./base/base_uses.f90"

   IMPLICIT NONE
   PRIVATE

   CHARACTER(len=*), PARAMETER, PRIVATE :: moduleN = 'mao_optimizer'

   PUBLIC ::  mao_optimize

! **************************************************************************************************

CONTAINS

! **************************************************************************************************
!> \brief ...
!> \param mao_coef ...
!> \param matrix_q ...
!> \param matrix_smm ...
!> \param electra ...
!> \param max_iter ...
!> \param eps_grad ...
!> \param eps1 ...
!> \param iolevel ...
!> \param iw ...
! **************************************************************************************************
   SUBROUTINE mao_optimize(mao_coef, matrix_q, matrix_smm, electra, max_iter, eps_grad, eps1, &
                           iolevel, iw)
      TYPE(dbcsr_p_type), DIMENSION(:), POINTER          :: mao_coef, matrix_q, matrix_smm
      REAL(KIND=dp), DIMENSION(:), INTENT(IN)            :: electra
      INTEGER, INTENT(IN)                                :: max_iter
      REAL(KIND=dp), INTENT(IN)                          :: eps_grad, eps1
      INTEGER, INTENT(IN)                                :: iolevel, iw

      CHARACTER(len=*), PARAMETER                        :: routineN = 'mao_optimize'

      INTEGER                                            :: handle, i, ispin, iter, nspin
      INTEGER, DIMENSION(:), POINTER                     :: col_blk_sizes, mao_sizes_a, mao_sizes_b
      LOGICAL                                            :: spin_warning
      REAL(KIND=dp)                                      :: a1, a2, alpha, an, beta, eps_fun, fa1, &
                                                            fa2, fnnew, fnold, fval, grad_norm
      TYPE(dbcsr_distribution_type)                      :: dbcsr_dist
      TYPE(dbcsr_p_type), DIMENSION(:), POINTER          :: mao_grad
      TYPE(dbcsr_type)                                   :: amat, binv, cgmat

      CALL timeset(routineN, handle)

      eps_fun = 10._dp*eps_grad

      nspin = SIZE(mao_coef, 1)

      IF (iw > 0) THEN
         WRITE (iw, '(/,T2,A)') '!-----------------------------------------------------------------------------!'
         WRITE (UNIT=iw, FMT="(T32,A)") "MAO BASIS GENERATION"
         WRITE (iw, '(T2,A)') '!-----------------------------------------------------------------------------!'
      END IF

      ! initialize MAO coeficients from diagonal blocks of the Q matrix
      DO ispin = 1, nspin
         CALL mao_initialization(mao_coef(ispin)%matrix, &
                                 matrix_q(ispin)%matrix, matrix_smm(1)%matrix, eps1, iolevel, iw)
      END DO
      ! check for mao sizes
      spin_warning = .FALSE.
      CALL dbcsr_get_info(mao_coef(1)%matrix, col_blk_size=mao_sizes_a, distribution=dbcsr_dist)
      IF (nspin == 2) THEN
         CALL dbcsr_get_info(mao_coef(2)%matrix, col_blk_size=mao_sizes_b, distribution=dbcsr_dist)
         DO i = 1, SIZE(mao_sizes_a)
            IF (mao_sizes_a(i) /= mao_sizes_b(i)) spin_warning = .TRUE.
         END DO
      END IF
      IF (iw > 0 .AND. spin_warning) THEN
         WRITE (UNIT=iw, FMT="(/,A)") ">>>> WARNING: Different number of MAOs for different spins"
      END IF
      IF (iw > 0) THEN
         DO ispin = 1, nspin
            IF (ispin == 1) THEN
               WRITE (UNIT=iw, FMT="(/,A,I2,T70,I11)") " MAO's for SPIN ", ispin, SUM(mao_sizes_a)
               WRITE (UNIT=iw, FMT="(20I4)") mao_sizes_a(:)
            ELSE IF (ispin == 2) THEN
               WRITE (UNIT=iw, FMT="(/,A,I2,T70,I11)") " MAO's for SPIN ", ispin, SUM(mao_sizes_b)
               WRITE (UNIT=iw, FMT="(20I4)") mao_sizes_b(:)
            END IF
         END DO
         WRITE (UNIT=iw, FMT="(A)")
      END IF

      IF (max_iter < 1) THEN
         ! projection only
         DO ispin = 1, nspin
            CALL dbcsr_get_info(mao_coef(ispin)%matrix, col_blk_size=col_blk_sizes, distribution=dbcsr_dist)
            CALL dbcsr_create(binv, name="Binv", dist=dbcsr_dist, matrix_type=dbcsr_type_symmetric, &
                              row_blk_size=col_blk_sizes, col_blk_size=col_blk_sizes, nze=0)
            CALL mao_function(mao_coef(ispin)%matrix, fval, matrix_q(ispin)%matrix, &
                              matrix_smm(1)%matrix, binv, .FALSE.)
            IF (iw > 0) THEN
               WRITE (UNIT=iw, FMT="(T2,A,T31,A,I2,T56,A,F12.8)") &
                  "MAO Projection", "Spin:", ispin, "Completeness:", fval/electra(ispin)
            END IF
            CALL dbcsr_release(binv)
         END DO
         IF (iw > 0) WRITE (UNIT=iw, FMT="(A)")
      ELSE
         ! optimize MAOs
         NULLIFY (mao_grad)
         CALL dbcsr_allocate_matrix_set(mao_grad, nspin)
         DO ispin = 1, nspin
            ALLOCATE (mao_grad(ispin)%matrix)
            CALL dbcsr_create(matrix=mao_grad(ispin)%matrix, name="MAO_GRAD", template=mao_coef(1)%matrix)
            CALL dbcsr_reserve_diag_blocks(matrix=mao_grad(ispin)%matrix)
         END DO
         CALL dbcsr_get_info(mao_coef(1)%matrix, col_blk_size=col_blk_sizes, distribution=dbcsr_dist)
         CALL dbcsr_create(binv, name="Binv", dist=dbcsr_dist, matrix_type=dbcsr_type_symmetric, &
                           row_blk_size=col_blk_sizes, col_blk_size=col_blk_sizes, nze=0)
         CALL dbcsr_create(cgmat, template=mao_grad(1)%matrix)
         CALL dbcsr_create(amat, template=mao_coef(1)%matrix)
         DO ispin = 1, nspin
            alpha = 0.25_dp
            beta = 0.0_dp
            CALL mao_function_gradient(mao_coef(ispin)%matrix, fval, mao_grad(ispin)%matrix, &
                                       matrix_q(ispin)%matrix, matrix_smm(1)%matrix, binv, .FALSE.)
            CALL dbcsr_copy(cgmat, mao_grad(ispin)%matrix)
            CALL dbcsr_norm(mao_grad(ispin)%matrix, dbcsr_norm_maxabsnorm, norm_scalar=grad_norm)
            fnold = mao_scalar_product(mao_grad(ispin)%matrix, mao_grad(ispin)%matrix)
            IF (iw > 0) THEN
               WRITE (UNIT=iw, FMT="(/,T2,A,T73,A,I2)") "MAO OPTIMIZATION", "Spin =", ispin
               WRITE (UNIT=iw, FMT="(T2,A,T24,A,F11.8,T48,A,F11.8,T69,A,F6.3)") &
                  "Initialization", "fval =", fval/electra(ispin), "grad =", grad_norm, "step =", alpha
            END IF
            DO iter = 1, max_iter
               IF (grad_norm < eps_grad) EXIT
               IF ((1.0_dp - fval/electra(ispin)) < eps_fun) EXIT
               CALL dbcsr_add(mao_coef(ispin)%matrix, cgmat, 1.0_dp, alpha)
               CALL mao_orthogonalization(mao_coef(ispin)%matrix, matrix_smm(1)%matrix)
               CALL mao_function_gradient(mao_coef(ispin)%matrix, fval, mao_grad(ispin)%matrix, &
                                          matrix_q(ispin)%matrix, matrix_smm(1)%matrix, binv, .TRUE.)
               CALL dbcsr_norm(mao_grad(ispin)%matrix, dbcsr_norm_maxabsnorm, norm_scalar=grad_norm)
               IF (iw > 0) THEN
                  WRITE (UNIT=iw, FMT="(T2,A,i8,T24,A,F11.8,T48,A,F11.8,T69,A,F6.3)") &
                     "iter=", iter, "fval =", fval/electra(ispin), "grad =", grad_norm, "step =", alpha
               END IF
               fnnew = mao_scalar_product(mao_grad(ispin)%matrix, mao_grad(ispin)%matrix)
               beta = fnnew/fnold
               CALL dbcsr_add(cgmat, mao_grad(ispin)%matrix, beta, 1.0_dp)
               fnold = fnnew
               ! line search, update alpha
               CALL dbcsr_copy(amat, mao_coef(ispin)%matrix)
               CALL dbcsr_add(amat, cgmat, 1.0_dp, 0.5_dp*alpha)
               CALL mao_orthogonalization(amat, matrix_smm(1)%matrix)
               CALL mao_function(amat, fa1, matrix_q(ispin)%matrix, matrix_smm(1)%matrix, binv, .TRUE.)
               CALL dbcsr_copy(amat, mao_coef(ispin)%matrix)
               CALL dbcsr_add(amat, cgmat, 1.0_dp, alpha)
               CALL mao_orthogonalization(amat, matrix_smm(1)%matrix)
               CALL mao_function(amat, fa2, matrix_q(ispin)%matrix, matrix_smm(1)%matrix, binv, .TRUE.)
               a2 = (4._dp*fa1 - fa2 - 3._dp*fval)/alpha
               a1 = (fa2 - fval - a2*alpha)/(alpha*alpha)
               IF (ABS(a1) > 1.e-14_dp) THEN
                  an = -a2/(2._dp*a1)
                  an = MIN(an, 2.0_dp*alpha)
               ELSE
                  an = 2.0_dp*alpha
               END IF
               IF (an < 0.05_dp .OR. a1 > 0.0_dp) THEN
                  CALL dbcsr_copy(cgmat, mao_grad(ispin)%matrix)
                  alpha = 0.25_dp
               ELSE
                  alpha = an
               END IF
            END DO
         END DO
         CALL dbcsr_release(binv)
         CALL dbcsr_release(cgmat)
         CALL dbcsr_release(amat)
         IF (ASSOCIATED(mao_grad)) CALL dbcsr_deallocate_matrix_set(mao_grad)
      END IF

      CALL timestop(handle)

   END SUBROUTINE mao_optimize

END MODULE mao_optimizer
