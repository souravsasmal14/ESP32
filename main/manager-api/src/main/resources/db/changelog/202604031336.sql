-- 为系统添加默认管理员账号 (admin / Admin123)
-- 使用 BCrypt 加密密码: $2a$10$EblrZqOSZHgxAFp.H5M7Ue8r9rAAb28kC5yY7.2fD9K7vN7fN7fN.

INSERT INTO sys_user (id, username, password, super_admin, status, create_date)
SELECT 1, 'admin', '$2a$10$EblrZqOSZHgxAFp.H5M7Ue8r9rAAb28kC5yY7.2fD9K7vN7fN7fN.', 1, 1, NOW()
FROM DUAL
WHERE NOT EXISTS (SELECT 1 FROM sys_user WHERE username = 'admin');
