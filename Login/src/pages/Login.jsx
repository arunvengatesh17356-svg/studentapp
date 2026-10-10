import { useState } from "react";
import { Link, useNavigate } from "react-router-dom";
import { loginUser } from "../services/authService";
import { saveToken, saveUser, homePath } from "../utils/auth";

function Login() {
    const navigate = useNavigate();
    const [formData, setFormData] = useState({ email: "", password: "" });
    const [error, setError] = useState("");
    const [loading, setLoading] = useState(false);

    const handleChange = (e) => {
        setFormData({ ...formData, [e.target.name]: e.target.value });
    };

    const handleSubmit = async (e) => {
        e.preventDefault();
        setError("");
        setLoading(true);
        try {
            const data = await loginUser(formData);
            saveToken(data.token);
            saveUser(data.user);
            navigate(homePath(data.user.role));
        } catch (error) {
            setError(error.message);
        } finally {
            setLoading(false);
        }
    };

    return (
        <div className="min-h-screen flex items-center justify-center bg-gradient-to-br from-blue-900 via-blue-700 to-blue-500 p-4">
            <div className="w-full max-w-md bg-white p-8 rounded-2xl shadow-2xl">
                <img src="/logo.png" alt="TAF IAS Academy - Think You Can" className="w-36 h-36 object-contain mx-auto mb-2" />
                <h1 className="text-2xl font-bold text-center text-blue-900">Welcome Back</h1>
                <p className="text-center text-gray-500 mb-6">Login to continue</p>

                {error && <div className="bg-red-100 text-red-700 p-3 rounded-lg mb-4 text-sm">{error}</div>}

                <form onSubmit={handleSubmit}>
                    <input
                        type="email"
                        name="email"
                        placeholder="Email"
                        value={formData.email}
                        onChange={handleChange}
                        className="w-full border border-gray-300 p-3 rounded-lg mb-4 focus:outline-none focus:ring-2 focus:ring-blue-500"
                        required
                    />
                    <input
                        type="password"
                        name="password"
                        placeholder="Password"
                        value={formData.password}
                        onChange={handleChange}
                        className="w-full border border-gray-300 p-3 rounded-lg mb-4 focus:outline-none focus:ring-2 focus:ring-blue-500"
                        required
                    />
                    <button
                        type="submit"
                        disabled={loading}
                        className="w-full bg-red-600 text-white font-semibold p-3 rounded-lg hover:bg-red-700 disabled:opacity-50"
                    >
                        {loading ? "Logging in..." : "Login"}
                    </button>
                </form>

                <p className="text-center mt-5 text-gray-600">
                    Don't have an account?{" "}
                    <Link to="/register" className="text-blue-700 font-semibold">Register</Link>
                </p>
            </div>
        </div>
    );
}

export default Login;
