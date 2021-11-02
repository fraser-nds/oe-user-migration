SELECT 
    id,
    username,
    first_name,
    last_name,
    email
FROM user
WHERE qualifications regexp @health_board;