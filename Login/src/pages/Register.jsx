import { useState } from "react";
import { Link, useNavigate } from "react-router-dom";
import { registerUser } from "../services/authService";

function Register() {
    const navigate = useNavigate();
    const [formData, setFormData] = useState({ name: "", email: "", password: "" });
    const [error, setError] = useState("");
    const [success, setSuccess] = useState("");
    const [loading, setLoading] = useState(false);

    const handleChange = (e) => {
        setFormData({ ...formData, [e.target.name]: e.target.value });
    };

    const handleSubmit = async (e) => {
        e.preventDefault();
        setError("");
        setSuccess("");
        setLoading(true);
        try {
            const data = await registerUser(formData);
            setSuccess(data.message);
            setFormData({ name: "", email: "", password: "" });
            setTimeout(() => navigate("/login"), 1000);
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
                <h1 className="text-2xl font-bold text-center text-blue-900">Create Account</h1>
                <p className="text-center text-gray-500 mb-6">Join TAF IAS Academy</p>

                {error && <div className="bg-red-100 text-red-700 p-3 rounded-lg mb-4 text-sm">{error}</div>}
                {success && <div className="bg-green-100 text-green-700 p-3 rounded-lg mb-4 text-sm">{success}</div>}

                <form onSubmit={handleSubmit}>
                    <input
                        type="text"
                        name="name"
                        placeholder="Full name"
                        value={formData.name}
                        onChange={handleChange}
                        className="w-full border border-gray-300 p-3 rounded-lg mb-4 focus:outline-none focus:ring-2 focus:ring-blue-500"
                        required
                    />
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
                        placeholder="Password (min 6 characters)"
                        minLength={6}
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
                        {loading ? "Creating..." : "Register"}
                    </button>
                </form>

                <p className="text-center mt-5 text-gray-600">
                    Already have an account?{" "}
                    <Link to="/login" className="text-blue-700 font-semibold">Login</Link>
                </p>
            </div>
        </div>
    );
}

export default Register;
