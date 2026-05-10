-- ==============================================================================
-- هذا الكود لضمان أن حساب (xxbaraa01xx@gmail.com) هو الـ Super Admin الوحيد
-- ويمنع ترقية أي حساب آخر إلى هذه الرتبة.
-- ==============================================================================

-- 1. التأكد من تفعيل بريد السوبر ادمن
UPDATE auth.users 
SET email_confirmed_at = NOW() 
WHERE email = 'xxbaraa01xx@gmail.com';

-- 2. ترقية الحساب الخاص بك ليكون super_admin وموافق عليه
UPDATE public.profiles 
SET role = 'super_admin', status = 'approved' 
WHERE id = (SELECT id FROM auth.users WHERE email = 'xxbaraa01xx@gmail.com');

-- 3. خفض رتبة أي حسابات super_admin أخرى (إن وجدت) إلى admin
UPDATE public.profiles 
SET role = 'admin' 
WHERE role = 'super_admin' 
  AND id != (SELECT id FROM auth.users WHERE email = 'xxbaraa01xx@gmail.com');

-- 4. إنشاء دالة (Function) لحماية رتبة السوبر ادمن
CREATE OR REPLACE FUNCTION public.enforce_single_super_admin()
RETURNS TRIGGER AS $$
DECLARE
  target_email text;
BEGIN
  -- جلب البريد الإلكتروني للحساب الذي يتم تعديله
  SELECT email INTO target_email FROM auth.users WHERE id = NEW.id;

  -- إذا تمت محاولة ترقية الحساب إلى super_admin
  IF NEW.role = 'super_admin' THEN
    -- السماح فقط إذا كان البريد الإلكتروني هو حسابك
    IF target_email != 'xxbaraa01xx@gmail.com' THEN
      RAISE EXCEPTION 'غير مسموح! فقط حساب xxbaraa01xx@gmail.com يمكنه أن يكون Super Admin.';
    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 5. تفعيل القاعدة (Trigger) على جدول profiles لمنع أي تغيير غير مصرح به
DROP TRIGGER IF EXISTS tr_enforce_single_super_admin ON public.profiles;

CREATE TRIGGER tr_enforce_single_super_admin
BEFORE INSERT OR UPDATE ON public.profiles
FOR EACH ROW
EXECUTE PROCEDURE public.enforce_single_super_admin();
