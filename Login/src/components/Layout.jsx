import { useEffect, useState } from "react";
import { NavLink, Outlet, useLocation, useNavigate } from "react-router-dom";
import { logoutUser } from "../services/authService";
import { getToken, getStoredUser, removeToken } from "../utils/auth";

const adminLinks = [
    { to: "/admin/users", label: "Users" },
    { to: "/admin/courses", label: "Courses" },
    { to: "/admin/batches", label: "Batches" },
    { to: "/admin/assignments", label: "Staff & Subjects" },
    { to: "/admin/exams", label: "Exams" }, 
    { to: "/admin/leaves", label: "Leave Requests" },
    { to: "/admin/purchases", label: "Purchases" },
    { to: "/profile", label: "Profile" },
];
const staffLinks = [
    { to: "/staff/dashboard", label: "Dashboard" },
    { to: "/staff/attendance", label: "Attendance" },
    { to: "/staff/exams", label: "Exams" }, 
    { to: "/staff/leaves", label: "Student Leaves" },
    { to: "/staff/my-leave", label: "My Leave" },
    { to: "/profile", label: "Profile" },
];
const studentLinks = [
    { to: "/courses", label: "Courses" },
    { to: "/my-courses", label: "My Courses" },
    { to: "/my-attendance", label: "Attendance" },
    { to: "/my-exams", label: "Exams" },
    { to: "/my-leaves", label: "Leave" },
    { to: "/profile", label: "Profile" },
];

function Layout() {
    const navigate = useNavigate();
    const location = useLocation();
    const user = getStoredUser();
    const links = user?.role === "student" ? studentLinks : user?.role === "staff" ? staffLinks : adminLinks;
    const [open, setOpen] = useState(false);

    // close the mobile menu after navigating, and on Escape
    useEffect(() => { setOpen(false); }, [location.pathname]);
    useEffect(() => {
        const h = (e) => e.key === "Escape" && setOpen(false);
        window.addEventListener("keydown", h);
        return () => window.removeEventListener("keydown", h);
    }, []);
    // stop the page behind the open menu from scrolling
    useEffect(() => {
        document.body.style.overflow = open ? "hidden" : "";
        return () => { document.body.style.overflow = ""; };
    }, [open]);

    const handleLogout = async () => {
        try {
            const t = getToken();
            if (t) await logoutUser(t);
        } catch (e) {
            console.error(e);
        } finally {
            removeToken();
            navigate("/login");
        }
    };

    return (
        <div className="min-h-screen bg-gray-100 md:flex">
            {/* Mobile top bar with hamburger */}
            <header className="md:hidden sticky top-0 z-30 bg-blue-900 text-white flex items-center gap-3 px-4 py-3 shadow">
                <button
                    onClick={() => setOpen(true)}
                    aria-label="Open menu"
                    aria-expanded={open}
                    className="p-2 -ml-2 rounded-lg hover:bg-blue-800"
                >
                    <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round">
                        <path d="M4 6h16M4 12h16M4 18h16" />
                    </svg>
                </button>
                <img src="/logo.png" alt="" className="h-8 w-8 object-contain" />
                <span className="font-bold">TAF IAS Academy</span>
            </header>

            {/* Dark backdrop (mobile only) */}
            {open && <div className="md:hidden fixed inset-0 bg-black/50 z-40" onClick={() => setOpen(false)} />}

            <aside
                className={`bg-blue-900 text-white flex flex-col w-64 md:w-60
                    fixed inset-y-0 left-0 z-50 transform transition-transform duration-200
                    ${open ? "translate-x-0" : "-translate-x-full"}
                    md:static md:translate-x-0 md:min-h-screen md:z-auto`}
            >
                <div className="flex items-center gap-3 px-5 py-5 border-b border-blue-800">
                    <img src="/logo.png" alt="" className="h-10 w-10 object-contain" />
                    <span className="font-bold flex-1">TAF IAS Academy</span>
                    <button onClick={() => setOpen(false)} aria-label="Close menu" className="md:hidden p-1 rounded hover:bg-blue-800">
                        <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round">
                            <path d="M6 6l12 12M18 6L6 18" />
                        </svg>
                    </button>
                </div>
                <nav className="flex flex-col flex-1 overflow-y-auto p-2 gap-1">
                    {links.map((l) => (
                        <NavLink
                            key={l.to}
                            to={l.to}
                            className={({ isActive }) =>
                                `px-4 py-2 rounded-lg whitespace-nowrap ${isActive ? "bg-white text-blue-900 font-semibold" : "hover:bg-blue-800"}`
                            }
                        >
                            {l.label}
                        </NavLink>
                    ))}
                </nav>
                <div className="p-3 border-t border-blue-800">
                    <p className="text-sm px-2 mb-2 truncate">
                        {user?.name} <span className="text-blue-300">({user?.role})</span>
                    </p>
                    <button onClick={handleLogout} className="w-full bg-red-600 hover:bg-red-700 rounded-lg px-4 py-2 font-semibold">
                        Logout
                    </button>
                </div>
            </aside>

            <main className="flex-1 p-4 md:p-8 min-w-0">
                <Outlet />
            </main>
        </div>
    );
}

export default Layout;
