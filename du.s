* du - print disk usage
*
* Itagaki Fumihiko 12-Dec-92  Create.
* 1.0
* Itagaki Fumihiko 10-Jan-93  GETPDB -> lea $10(a0),a0
* Itagaki Fumihiko 20-Jan-93  ���� - �� -- �̈����̕ύX
* Itagaki Fumihiko 22-Jan-93  �X�^�b�N���g��
* 1.1
* Itagaki Fumihiko 04-Jan-94  -B <size> �� -B<size> �Ə����Ă��悢
* Itagaki Fumihiko 04-Jan-94  \ �� \/ �ƕ\�������s����C��
* 1.2
*
* Usage: du [ -DLSacsx ] [ -B blocksize ] [ -- ] [ file ] ...

.include doscall.h
.include error.h
.include limits.h
.include stat.h
.include chrcode.h

.xref DecodeHUPAIR
.xref getlnenv
.xref issjis
.xref toupper
.xref atou
.xref utoa
.xref strlen
.xref strcpy
.xref stpcpy
.xref strbot
.xref strfor1
.xref divul
.xref strip_excessive_slashes
.xref contains_dos_wildcard
.xref skip_root

REQUIRED_OSVER		equ	$200			*  2.00�ȍ~

MAXRECURSE	equ	64	*  �T�u�f�B���N�g�����������邽�߂ɍċA����񐔂̏���D
				*  MAXDIR �i�p�X���̃f�B���N�g���� "/1/2/3/../" �̒����j
				*  �� 64 �ł��邩��A31�ŏ[���ł��邪�C
				*  �V���{���b�N�E�����N���l������ 64 �Ƃ���D
				*  �X�^�b�N�ʂɂ������D

FATCHK_STATIC	equ	256	*  �ÓI�o�b�t�@��fatchk�ł���悤�ɂ��Ă���FAT�`�F�C����

FLAG_a		equ	0
FLAG_s		equ	1
FLAG_S		equ	2
FLAG_c		equ	3
FLAG_D		equ	4
FLAG_L		equ	5
FLAG_B		equ	6
FLAG_x		equ	7

LNDRV_O_CREATE		equ	4*2
LNDRV_O_OPEN		equ	4*3
LNDRV_O_DELETE		equ	4*4
LNDRV_O_MKDIR		equ	4*5
LNDRV_O_RMDIR		equ	4*6
LNDRV_O_CHDIR		equ	4*7
LNDRV_O_CHMOD		equ	4*8
LNDRV_O_FILES		equ	4*9
LNDRV_O_RENAME		equ	4*10
LNDRV_O_NEWFILE		equ	4*11
LNDRV_O_FATCHK		equ	4*12
LNDRV_realpathcpy	equ	4*16
LNDRV_LINK_FILES	equ	4*17
LNDRV_OLD_LINK_FILES	equ	4*18
LNDRV_link_nest_max	equ	4*19
LNDRV_getrealpath	equ	4*20

****************************************************************
.text

start:
		bra.s	start1
		dc.b	'#HUPAIR',0
start1:
		lea	stack_bottom,a7			*  A7 := �X�^�b�N�̒�
		DOS	_VERNUM
		cmp.w	#REQUIRED_OSVER,d0
		bcs	dos_version_mismatch

		lea	$10(a0),a0			*  A0 : PDB�A�h���X
		move.l	a7,d0
		sub.l	a0,d0
		move.l	d0,-(a7)
		move.l	a0,-(a7)
		DOS	_SETBLOCK
		addq.l	#8,a7
	*
	*  lndrv�풓�`�F�b�N
	*
		bsr	getlnenv
		move.l	d0,lndrv
	*
	*  �������ъi�[�G���A���m�ۂ���
	*
		lea	1(a2),a0			*  A0 := �R�}���h���C���̕�����̐擪�A�h���X
		bsr	strlen				*  D0.L := �R�}���h���C���̕�����̒���
		addq.l	#1,d0
		bsr	malloc
		bmi	insufficient_memory

		movea.l	d0,a1				*  A1 := �������ъi�[�G���A�̐擪�A�h���X
	*
	*  �������f�R�[�h���C���߂���
	*
		bsr	DecodeHUPAIR			*  �������f�R�[�h����
		movea.l	a1,a0				*  A0 : �����|�C���^
		move.l	d0,d7				*  D7.L : �����J�E���^
		moveq	#0,d5				*  D5.L : �t���O
decode_opt_loop1:
		tst.l	d7
		beq	decode_opt_done

		cmpi.b	#'-',(a0)
		bne	decode_opt_done

		tst.b	1(a0)
		beq	decode_opt_done

		subq.l	#1,d7
		addq.l	#1,a0
		move.b	(a0)+,d0
		cmp.b	#'-',d0
		bne	decode_opt_loop2

		tst.b	(a0)+
		beq	decode_opt_done

		subq.l	#1,a0
decode_opt_loop2:
		moveq	#FLAG_a,d1
		cmp.b	#'a',d0
		beq	set_option

		moveq	#FLAG_s,d1
		cmp.b	#'s',d0
		beq	set_option

		moveq	#FLAG_S,d1
		cmp.b	#'S',d0
		beq	set_option

		moveq	#FLAG_c,d1
		cmp.b	#'c',d0
		beq	set_option

		moveq	#FLAG_x,d1
		cmp.b	#'x',d0
		beq	set_option

		moveq	#FLAG_D,d1
		cmp.b	#'D',d0
		beq	set_option

		cmp.b	#'L',d0
		beq	set_option_L

		move.l	#1024,d1
		cmp.b	#'k',d0
		beq	set_blocksize

		cmp.b	#'B',d0
		beq	parse_blocksize

		moveq	#1,d1
		tst.b	(a0)
		beq	bad_option_1

		bsr	issjis
		bne	bad_option_1

		moveq	#2,d1
bad_option_1:
		move.l	d1,-(a7)
		pea	-1(a0)
		move.w	#2,-(a7)
		lea	msg_illegal_option(pc),a0
		bsr	werror_myname_and_msg
		DOS	_WRITE
		lea	10(a7),a7
		bra	usage

parse_blocksize:
		tst.b	(a0)
		bne	parse_blocksize_1

		subq.l	#1,d7
		bcs	too_few_args

		addq.l	#1,a0
parse_blocksize_1:
		bsr	atou
		bne	bad_blocksize

		tst.l	d1
		beq	bad_blocksize

		tst.b	(a0)
		bne	bad_blocksize
set_blocksize:
		move.l	d1,blocksize
		bset	#FLAG_B,d5
		bra	set_option_done

set_option_L:
		bset	#FLAG_L,d5
set_option:
		bset	d1,d5
set_option_done:
		move.b	(a0)+,d0
		bne	decode_opt_loop2
		bra	decode_opt_loop1

decode_opt_done:
	*
	*  �t�@�C����������������
	*
		tst.l	d7
		bne	args_ok

		lea	default_arg(pc),a0
		moveq	#1,d7
args_ok:
	*
	*  ������stat���郋�[�v
	*
		moveq	#0,d6				*  D6.W : �I���X�e�[�^�X
		moveq	#0,d1
du_args_loop:
		movea.l	a0,a1
		bsr	strfor1
		exg	a0,a1
		move.b	(a0),d0
		beq	du_args_1

		cmpi.b	#':',1(a0)
		bne	du_args_1

		bsr	toupper
		move.b	d0,(a0)
du_args_1:
		bsr	strip_excessive_slashes
		bsr	du_arg
		add.l	d0,d1
		movea.l	a1,a0
		subq.l	#1,d7
		bne	du_args_loop

		btst	#FLAG_c,d5
		beq	exit_program

		lea	str_total(pc),a0
		move.l	d1,d0
		bsr	output
exit_program:
		move.w	d6,-(a7)
		DOS	_EXIT2

bad_blocksize:
		lea	msg_bad_blocksize(pc),a0
		bra	werror_usage

too_few_args:
		lea	msg_too_few_args(pc),a0
werror_usage:
		bsr	werror_myname_and_msg
usage:
		lea	msg_usage(pc),a0
		bsr	werror
		moveq	#1,d6
		bra	exit_program

dos_version_mismatch:
		lea	msg_dos_version_mismatch(pc),a0
		bra	error_exit_3

insufficient_memory:
		lea	msg_no_memory(pc),a0
error_exit_3:
		bsr	werror_myname_and_msg
		moveq	#3,d6
		bra	exit_program
****************************************************************
* du_arg - 1�̈�������������
*
* CALL
*      A0     �����̐擪�A�h���X
*
* RETURN
*      D0.L   �T�C�Y
****************************************************************
du_arg:
		movem.l	d1/a0-a3,-(a7)
		movea.l	a0,a3
		moveq	#-1,d0
		bsr	strlen
		cmp.l	#MAXPATH,d0
		bhi	du_arg_too_long_path

		bsr	contains_dos_wildcard
		bne	du_arg_nofile

		btst	#FLAG_D,d5
		bsr	xstat
		bsr	stat2
		bmi	du_arg_nofile
		bne	du_arg_dir

		lea	filesbuf(pc),a1
		btst.b	#MODEBIT_DIR,ST_MODE(a1)
		bne	du_arg_dir

		move.l	a0,-(a7)
		lea	stat_pathname(pc),a0
		bsr	filesize
		movea.l	(a7)+,a0
		bsr	output
		bra	du_arg_return

du_arg_dir:
		movea.l	a0,a1
		btst	#FLAG_x,d5
		beq	du_arg_dir_1

		lea	stat_pathname(pc),a0
		bsr	get_driveno
		move.w	d0,drive
du_arg_dir_1:
		lea	pathname(pc),a0
		bsr	stpcpy
		exg	a0,a1
		bsr	skip_root
		exg	a0,a1
		beq	du_arg_dir_2

		move.b	#'/',(a0)+
du_arg_dir_2:
		lea	stat_pathname(pc),a1
		bsr	du_directory
		lea	pathname(pc),a0
		bsr	output
du_arg_return:
		movem.l	(a7)+,d1/a0-a3
		rts

du_arg_nofile:
		movea.l	a3,a0
		bsr	werror_myname_and_msg
		lea	msg_nofile(pc),a0
		bsr	werror
		moveq	#2,d6
du_arg_return_0:
		moveq	#0,d0
		bra	du_arg_return

du_arg_too_long_path:
		movea.l	a3,a0
		bsr	too_long_path
		bra	du_arg_return_0
****************************************************************
* du_directory
*
* CALL
*      (pathname)   �p�X���i���̂܂� *.* �� cat �ł���`�ł��邱�Ɓj
*      A0           (pathname)�̖����̃A�h���X�iNUL�łȂ��Ă��悢�j
*      A1           fatchk���ׂ��p�X��
*
* RETURN
*      D0.L         �T�C�Y
*      D1/A0-A2     �j��
*
* NOTE
*      �ċA����D�X�^�b�N�ɒ���
****************************************************************
du_directory_filesbuf       = -((STATBUFSIZE+1)>>1<<1)
du_directory_corrected_name = du_directory_filesbuf-128
du_directory_namebottom     = du_directory_corrected_name-4
du_directory_tailptr        = du_directory_namebottom-4
du_directory_total          = du_directory_tailptr-4
du_directory_numentry       = du_directory_total-4
du_directory_autosize       = -du_directory_numentry

du_recurse_stacksize	equ	du_directory_autosize+4*2	* 4*2 ... A6/PC

du_directory:
		link	a6,#du_directory_numentry
		clr.l	du_directory_total(a6)
		move.l	a0,du_directory_namebottom(a6)
		move.l	a0,-(a7)
		lea	du_directory_corrected_name(a6),a0
		bsr	strcpy
		movea.l	(a7)+,a0
		lea	pathname(pc),a1
		move.l	a0,d0
		sub.l	a1,d0
		cmp.l	#MAXHEAD,d0
		bhi	du_directory_too_long_path

		move.l	a0,du_directory_tailptr(a6)
		lea	str_dos_allfile(pc),a1
		bsr	strcpy
		move.w	#MODEVAL_ALL,-(a7)
		pea	pathname(pc)
		pea	du_directory_filesbuf(a6)
		DOS	_FILES
		lea	10(a7),a7
				*  chdir �ō~��Ȃ��� files("*.*") ��������������Ƃ�������
				*  �m���߂�ꂽ���C�����Ȃ�Ƃ͌����Ă����X�S�̂�5%���x�ł�
				*  �邵�C�����ɂ���Ă͋t�ɒx���Ȃ邱�Ƃ��l������D����ɁC
				*
				*  o �f�B���N�g���ւ̃V���{���b�N�E�����N�ɍ~����
				*    chdir("..") �ł͖߂�Ȃ��̂ŁC���̏ꍇ�̓J�����g�E�f�B
				*    ���N�g����ۑ����Ă�������
				*
				*  o �f�B���N�g�������̏�����͂ǂ��ɂ��߂�Ȃ�����
				*
				*  o ^C�������ꂽ���ƃf�B���N�g���ɕ��A���Ă���I�����鏈
				*    ��
				*
				*  �Ȃǂ��s��˂΂Ȃ炸�C�v���O���������G�ɂȂ�D�����̏�
				*  �����e�K�v�ȏꍇ�����f�s���悤�ɂ���ƁC�v���O�����͂���
				*  �ɕ��G�ɂȂ�D
				*
				*  �܂��C�e�f�B���N�g���ւ̃V���{���b�N�E�����N�f�̃p�X����
				*  �� chdir �ł���Ƃ����O�񂪁C�����ɂ킽���ĕۏ؂���Ȃ���
				*  ���m��Ȃ��i�C�����Ȃ��ł��Ȃ��j�D�������� chdir �́e�w��
				*  �h���C�u�̃J�����g�E�f�B���N�g����ύX����f�t�@���N�V��
				*  ���ł��邩��C�h���C�u���܂������� chdir ���� lndrv 1.00
				*  �̎d�l�́CHuman68k �̖{���̎d�l���班�X��E���Ă���D����
				*  �悤�Ȋϓ_����Clndrv �� chdir �̎d�l�Ɉˑ�����̂͏��X��
				*  ���ƌ����D�Ȃ�� lndrv �� chdir �𒼐ڂ͌Ă΂��ɁC�ړI��
				*  �f�B���N�g���̃p�X���� readlink �ɂ��ǂݎ���� chdir ��
				*  ��Ηǂ��i���̏����́C���̃��[�`���ɓ��B����܂łɊ��ɍs
				*  ���Ă��锤�ł��邩��C���ԓI�ɑ����邱�Ƃ͂Ȃ��j�̂����C
				*  ������܂��v���O�����𕡎G�ɂ��Ă��܂��D
				*
				*  �Ƃ����킯�ŁCchdir�����͎̂Ă��D
				*
				*  ������ Human68k �ł́C���̂܂܂ł������Ȃ�\��������D
		clr.l	du_directory_numentry(a6)
du_directory_loop:
		tst.l	d0
		bmi	du_directory_done

		addq.l	#1,du_directory_numentry(a6)
		lea	du_directory_filesbuf+ST_NAME(a6),a0
		bsr	is_reldir
		beq	du_directory_next

		movea.l	a0,a1
		movea.l	du_directory_tailptr(a6),a0
		bsr	stpcpy

		moveq	#0,d0
		lea	du_directory_filesbuf(a6),a1
		lea	pathname(pc),a2
		btst	#FLAG_L,d5
		beq	du_directory_not_link

		btst.b	#MODEBIT_LNK,ST_MODE(a1)
		beq	du_directory_not_link

		exg	a0,a2
		bsr	stat
		exg	a0,a2
		bsr	stat2
		bmi	du_directory_next

		lea	stat_pathname(pc),a2
		lea	filesbuf(pc),a1
du_directory_not_link:
		move.l	d0,d1
		btst	#FLAG_x,d5
		beq	du_directory_drive_ok

		exg	a0,a2
		bsr	get_driveno
		exg	a0,a2
		cmp.w	drive,d0
		bne	du_directory_next
du_directory_drive_ok:
		tst.l	d1
		bne	du_directory_dir

		btst.b	#MODEBIT_VOL,ST_MODE(a1)
		bne	du_directory_vol

		btst.b	#MODEBIT_DIR,ST_MODE(a1)
		bne	du_directory_dir
		bra	du_directory_file

du_directory_vol:
		btst	#FLAG_B,d5
		bne	du_directory_next
du_directory_file:
		movea.l	a2,a0
		bsr	filesize
		btst	#FLAG_a,d5
		beq	du_directory_continue

		lea	pathname(pc),a0
		bsr	output
		bra	du_directory_continue

du_directory_dir:
		btst	#FLAG_S,d5
		beq	du_directory_recurse

		btst	#FLAG_s,d5
		beq	du_directory_recurse

		btst	#FLAG_a,d5
		beq	du_directory_next
du_directory_recurse:
		cmpa.l	#stack_lower+du_recurse_stacksize,a7	*  �ċA�ɔ����ăX�^�b�N���x�����`�F�b�N
		bhs	recurse_ok

		lea	pathname(pc),a0
		bsr	werror_myname_and_msg
		lea	msg_dir_too_deep(pc),a0
		bsr	werror
		moveq	#2,d6
		bra	du_directory_next

recurse_ok:
		move.b	#'/',(a0)+
		movea.l	a2,a1
		bsr	du_directory			* �m�ċA�n
		btst	#FLAG_s,d5
		bne	du_directory_dir_1

		lea	pathname(pc),a0
		bsr	output
du_directory_dir_1:
		btst	#FLAG_S,d5
		bne	du_directory_next
du_directory_continue:
		add.l	d0,du_directory_total(a6)
du_directory_next:
		pea	du_directory_filesbuf(a6)
		DOS	_NFILES
		addq.l	#4,a7
		bra	du_directory_loop

du_directory_done:
		lea	pathname(pc),a0
		movea.l	du_directory_namebottom(a6),a1
		clr.b	(a1)
		lea	du_directory_corrected_name(a6),a0
		move.l	du_directory_numentry(a6),d0
		bsr	dirsize
		add.l	d0,du_directory_total(a6)
du_directory_return:
		move.l	du_directory_total(a6),d0
		unlk	a6
		rts

du_directory_too_long_path:
		bsr	too_long_path
		bra	du_directory_done
*****************************************************************
* output
*
* CALL
*      A0     �p�X��
*      D0.L   �T�C�Y
*
* RETURN
*      none
*****************************************************************
output:
		movem.l	d0/a0,-(a7)
		move.l	a0,-(a7)
		lea	utoabuf(pc),a0
		bsr	utoa
		move.l	a0,-(a7)
		DOS	_PRINT
		move.w	#HT,(a7)
		DOS	_PUTCHAR
		addq.l	#4,a7
		DOS	_PRINT
		pea	str_newline(pc)
		DOS	_PRINT
		addq.l	#8,a7
		movem.l	(a7)+,d0/a0
		rts
*****************************************************************
* filesize - ��f�B���N�g���̃T�C�Y�����߂�
*
* CALL
*      A0     �p�X��
*      A1     filebuf
*      CCR    �����N��ǂ��Ȃ� NE
*
* RETURN
*      D0.L   �T�C�Y
*      (fatchkbuf)   �j��
*****************************************************************
filesize:
		btst	#FLAG_B,d5
		beq	sectorsize

		move.l	ST_SIZE(a1),d0
*****************************************************************
* pseudosize - �G���g���𕡐�����̂ɕK�v�ȃu���b�N�������߂�
*
* CALL
*      D0.L   �o�C�g��
*
* RETURN
*      D0.L   �u���b�N��
*****************************************************************
pseudosize:
		move.l	d1,-(a7)
		move.l	blocksize,d1
		bsr	divul
		addq.l	#1,d0
		move.l	(a7)+,d1
		rts
*****************************************************************
* dirsize - �f�B���N�g���̃T�C�Y�����߂�
*
* CALL
*      A0     �p�X��
*      D0.L   �G���g����
*
* RETURN
*      D0.L   �T�C�Y
*      (fatchkbuf), (nameck_buffer)   �j��
*****************************************************************
dirsize:
		lsl.l	#5,d0				*  x32
		btst	#FLAG_B,d5
		bne	pseudosize
*****************************************************************
* sectorsize - �G���g���̎��ۂ̘_���Z�N�^�������߂�
*
* CALL
*      A0     �p�X��
*
* RETURN
*      D0.L   �T�C�Y
*      (fatchkbuf)   �j��
*****************************************************************
sectorsize:
		movem.l	d1-d2/a1,-(a7)
		moveq	#0,d2
		lea	fatchkbuf(pc),a1
		move.w	#2+8*FATCHK_STATIC+4,-(a7)
		move.l	a1,d0
		bset	#31,d0
		move.l	d0,-(a7)
		move.l	a0,-(a7)
		DOS	_FATCHK
		lea	10(a7),a7
		cmp.l	#EBADPARAM,d0
		bne	fatchk_success

		move.l	#65520,d0
		move.l	d0,d1
		bsr	malloc
		move.l	d0,d2
		bpl	fatchk_malloc_ok

		sub.l	#$81000000,d0
		cmp.l	#2+8*FATCHK_STATIC+4+4,d0
		blo	insufficient_memory

		move.l	d0,d1
		bsr	malloc
		move.l	d0,d2
		bmi	insufficient_memory
fatchk_malloc_ok:
		subq.w	#4,d1
		move.w	d1,-(a7)
		bset	#31,d2
		move.l	d2,-(a7)
		bclr	#31,d2
		move.l	a0,-(a7)
		DOS	_FATCHK
		lea	10(a7),a7
		cmp.l	#EBADPARAM,d0
		beq	insufficient_memory

		movea.l	d2,a1
fatchk_success:
		moveq	#0,d1
		tst.l	d0
		bmi	calc_sector_size_done

		addq.l	#2,a1
calc_sector_size_loop:
		tst.l	(a1)+
		beq	calc_sector_size_done

		add.l	(a1)+,d1
		bra	calc_sector_size_loop

calc_sector_size_done:
		move.l	d2,d0
		beq	sector_size_ok

		bsr	free
sector_size_ok:
		move.l	d1,d0
		movem.l	(a7)+,d1-d2/a1
		rts
*****************************************************************
xstat:
		bne	stat
lstat:
		movem.l	d1-d7/a0-a6,-(a7)
		move.l	#LNDRV_realpathcpy,d1
		bra	xstat_1

stat:
		movem.l	d1-d7/a0-a6,-(a7)
		move.l	#LNDRV_getrealpath,d1
xstat_1:
		tst.l	lndrv
		beq	xstat_3

		clr.l	-(a7)
		DOS	_SUPER				*  �X�[�p�[�o�C�U�E���[�h�ɐ؂芷����
		addq.l	#4,a7
		move.l	d0,-(a7)			*  �O�� SSP �̒l
		movea.l	lndrv,a1
		movea.l	(a1,d1.l),a1
		move.l	a0,-(a7)
		pea	stat_pathname(pc)
		jsr	(a1)
		addq.l	#8,a7
		moveq	#-1,d1
		tst.l	d0
		bmi	xstat_2

		movea.l	lndrv,a1
		movea.l	LNDRV_O_FILES(a1),a1
		move.w	#MODEVAL_ALL,-(a7)
		pea	stat_pathname(pc)
		pea	filesbuf(pc)
		movea.l	a7,a6
		jsr	(a1)
		lea	10(a7),a7
		move.l	d0,d1
xstat_2:
		DOS	_SUPER				*  ���[�U�E���[�h�ɖ߂�
		addq.l	#4,a7
		move.l	d1,d0
		bra	xstat_return

xstat_3:
		move.l	a0,a1
		lea	stat_pathname(pc),a0
		bsr	strcpy
		move.w	#MODEVAL_ALL,-(a7)
		move.l	a1,-(a7)
		pea	filesbuf(pc)
		DOS	_FILES
		lea	10(a7),a7
xstat_return:
		movem.l	(a7)+,d1-d7/a0-a6
		tst.l	d0
		rts
*****************************************************************
stat2:
		bpl	stat2_return_0

		addq.l	#1,d0
		beq	stat2_fail

		pea	nameck_buffer(pc)
		pea	stat_pathname(pc)
		DOS	_NAMECK
		addq.l	#8,a7
		tst.l	d0
		bmi	stat2_fail

		tst.b	nameck_buffer+67
		bne	stat2_fail

		move.l	a0,-(a7)
		lea	nameck_buffer(pc),a0
		bsr	strip_excessive_slashes
		bsr	lstat
		movea.l	(a7)+,a0
		bpl	stat2_return_0

		addq.l	#1,d0
		beq	stat2_fail

		tst.b	nameck_buffer+3
		beq	stat2_return_1
stat2_fail:
		moveq	#-1,d0
		rts

stat2_return_1:
		moveq	#1,d0
		rts

stat2_return_0:
		moveq	#0,d0
		rts
****************************************************************
get_driveno:
		tst.l	d0
		bne	get_driveno_root

		move.l	a1,-(a7)
		lea	fatchkbuf(pc),a1
		move.l	a1,d0
		bset	#31,d0
		move.w	#14,-(a7)
		move.l	d0,-(a7)
		move.l	a0,-(a7)
		DOS	_FATCHK
		lea	10(a7),a7
		move.w	(a1),d0
		movea.l	(a7)+,a1
		rts

get_driveno_root:
		moveq	#0,d0
		move.b	(a0),d0
		sub.w	#'A'-1,d0
		rts
****************************************************************
* is_reldir - ���O�� . �� .. �ł��邩�ǂ����𒲂ׂ�
*
* CALL
*      A0     ���O
*
* RETURN
*      CCR    ���O�� . �� .. �Ȃ�� EQ
****************************************************************
is_reldir:
		moveq	#0,d0
		cmpi.b	#'.',(a0)
		bne	is_reldir_return

		tst.b	1(a0)
		beq	is_reldir_return

		cmpi.b	#'.',1(a0)
		bne	is_reldir_return

		tst.b	2(a0)
is_reldir_return:
		rts
*****************************************************************
malloc:
		move.l	d0,-(a7)
		DOS	_MALLOC
		addq.l	#4,a7
		tst.l	d0
		rts
*****************************************************************
free:
		move.l	d0,-(a7)
		DOS	_MFREE
		addq.l	#4,a7
		rts
*****************************************************************
werror_myname_and_msg:
		move.l	a0,-(a7)
		lea	msg_myname(pc),a0
		bsr	werror
		movea.l	(a7)+,a0
werror:
		move.l	d0,-(a7)
		bsr	strlen
		move.l	d0,-(a7)
		move.l	a0,-(a7)
		move.w	#2,-(a7)
		DOS	_WRITE
		lea	10(a7),a7
		move.l	(a7)+,d0
		rts
*****************************************************************
too_long_path:
		bsr	werror_myname_and_msg
		move.l	a0,-(a7)
		lea	msg_too_long_path(pc),a0
		bsr	werror
		movea.l	(a7)+,a0
		moveq	#2,d6
		rts
*****************************************************************
.data

	dc.b	0
	dc.b	'## du 1.2 ##  Copyright(C)1992-94 by Itagaki Fumihiko',0

**
**  �萔
**

msg_myname:			dc.b	'du: ',0
msg_dos_version_mismatch:	dc.b	'�o�[�W����2.00�ȍ~��Human68k���K�v�ł�',CR,LF,0
msg_too_long_path:		dc.b	': �p�X�������߂��܂�',CR,LF,0
msg_nofile:			dc.b	': ���̂悤�ȃt�@�C����f�B���N�g���͂���܂���',CR,LF,0
msg_dir_too_deep:		dc.b	': �f�B���N�g�����[�߂��ď����ł��܂���',CR,LF,0
msg_no_memory:			dc.b	'������������܂���',CR,LF,0
msg_illegal_option:		dc.b	'�s���ȃI�v�V���� -- ',0
msg_bad_blocksize:		dc.b	'�u���b�N���̎w�肪����������܂���',0
msg_too_few_args:		dc.b	'����������܂���',0
msg_usage:			dc.b	CR,LF
				dc.b	'�g�p�@:  du [-DLSacksx] [-B <�u���b�N��>] [--] [<�p�X��>] ...'
str_newline:			dc.b	CR,LF,0
default_arg:			dc.b	'.',0
str_dos_allfile:		dc.b	'*.*',0
str_total:			dc.b	'���v',0
*****************************************************************
.bss

.even
lndrv:			ds.l	1
blocksize:		ds.l	1
drive:			ds.w	1
utoabuf:		ds.b	11
.even
filesbuf:		ds.b	STATBUFSIZE
nameck_buffer:		ds.b	91
pathname:		ds.b	MAXPATH+1
stat_pathname:		ds.b	128
.even
fatchkbuf:		ds.b	2+8*FATCHK_STATIC+4
.even
		ds.b	16384
		*  �}�[�W���ƃX�[�p�[�o�C�U�E�X�^�b�N�Ƃ����˂�16KB�m�ۂ��Ă����D
stack_lower:
		ds.b	du_recurse_stacksize*(MAXRECURSE+1)
		*  �K�v�ȃX�^�b�N�ʂ́C�ċA�̓x�ɏ�����X�^�b�N�ʂƂ��̉񐔂ƂŌ��܂�D
		ds.b	16
.even
stack_bottom:
*****************************************************************

.end start
