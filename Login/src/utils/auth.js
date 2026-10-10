const TOKEN_KEY = "auth_token";
const USER_KEY = "auth_user";

export const saveToken = (token) => localStorage.setItem(TOKEN_KEY, token);
export const getToken = () => localStorage.getItem(TOKEN_KEY);

export const saveUser = (user) => localStorage.setItem(USER_KEY, JSON.stringify(user));
export const getStoredUser = () => {
    try {
        return JSON.parse(localStorage.getItem(USER_KEY));
    } catch {
        return null;
    }
};

export const removeToken = () => {
    localStorage.removeItem(TOKEN_KEY);
    localStorage.removeItem(USER_KEY);
};

export const isLoggedIn = () => !!localStorage.getItem(TOKEN_KEY);

/** Where each role lands after login. */
export const homePath = (role) =>
    role === "student" ? "/courses" : role === "staff" ? "/staff/dashboard" : "/admin/users";
