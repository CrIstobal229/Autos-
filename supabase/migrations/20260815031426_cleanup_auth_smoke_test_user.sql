-- Cleanup: T-019 verified email/password signup is enabled by calling the real
-- Auth API directly (POST /auth/v1/signup). That call may have created a user row
-- before hitting the email rate limit; remove it if so.
delete from auth.users where email = 't019.signup.check.autosusados@gmail.com';
