const API =
    import.meta.env.VITE_API_BASE_URL ||
    "http://localhost/App/backend/public/api";

const parseResponse = async (response) => {
    const text = await response.text();

    console.log("API Status:", response.status);
    console.log("API Response:", text);

    if (!text) {
        throw new Error(
            `Server returned an empty response. HTTP Status: ${response.status}. Check VITE_API_BASE_URL in .env (${API}) and restart npm run dev.`
        );
    }

    let data;

    try {
        data = JSON.parse(text);
    } catch (error) {
        console.error("Invalid JSON from server:", text);

        throw new Error(
            `Server returned invalid JSON. HTTP Status: ${response.status}`
        );
    }

    return data;
};


export const registerUser = async (userData) => {
    const response = await fetch(`${API}/register`, {
        method: "POST",
        headers: {
            "Content-Type": "application/json",
            "Accept": "application/json",
        },
        body: JSON.stringify(userData),
    });

    const data = await parseResponse(response);

    if (!response.ok) {
        throw new Error(data.message || "Registration failed");
    }

    return data;
};


export const loginUser = async (userData) => {
    const response = await fetch(`${API}/login`, {
        method: "POST",
        headers: {
            "Content-Type": "application/json",
            "Accept": "application/json",
        },
        body: JSON.stringify(userData),
    });

    const data = await parseResponse(response);

    if (!response.ok) {
        throw new Error(data.message || "Login failed");
    }

    return data;
};


export const getUser = async (token) => {
    const response = await fetch(`${API}/user`, {
        method: "GET",
        headers: {
            "Authorization": `Bearer ${token}`,
            "Accept": "application/json",
        },
    });

    const data = await parseResponse(response);

    if (!response.ok) {
        throw new Error(data.message || "Failed to get user");
    }

    return data;
};


export const logoutUser = async (token) => {
    const response = await fetch(`${API}/logout`, {
        method: "POST",
        headers: {
            "Authorization": `Bearer ${token}`,
            "Accept": "application/json",
        },
    });

    const data = await parseResponse(response);

    if (!response.ok) {
        throw new Error(data.message || "Logout failed");
    }

    return data;
};