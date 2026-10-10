import { useEffect } from "react";

export const inputCls =
    "w-full border border-gray-300 p-2.5 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500 bg-white";

export function Field({ label, children }) {
    return (
        <label className="block mb-3">
            <span className="block text-sm font-medium text-gray-700 mb-1">{label}</span>
            {children}
        </label>
    );
}

export function Alert({ type = "error", children }) {
    if (!children) return null;
    const c = type === "error" ? "bg-red-100 text-red-700" : "bg-green-100 text-green-700";
    return <div className={`${c} p-3 rounded-lg mb-4 text-sm`}>{children}</div>;
}

export function Button({ variant = "primary", className = "", ...p }) {
    const v = {
        primary: "bg-blue-900 text-white hover:bg-blue-800",
        danger: "bg-red-600 text-white hover:bg-red-700",
        ghost: "bg-gray-200 text-gray-800 hover:bg-gray-300",
    }[variant];
    return <button {...p} className={`${v} px-4 py-2 rounded-lg font-semibold disabled:opacity-50 ${className}`} />;
}

export function PageHeader({ title, action }) {
    return (
        <div className="flex items-center justify-between mb-6 gap-3 flex-wrap">
            <h1 className="text-2xl font-bold text-blue-900">{title}</h1>
            {action}
        </div>
    );
}

export function Modal({ title, onClose, children, size = "md" }) {
    useEffect(() => {
        const h = (e) => e.key === "Escape" && onClose();
        window.addEventListener("keydown", h);
        return () => window.removeEventListener("keydown", h);
    }, [onClose]);

    return (
        <div className="fixed inset-0 bg-black/50 flex items-center justify-center p-4 z-50" onMouseDown={onClose}>
            <div
                className={`bg-white rounded-xl w-full ${size === "xl" ? "max-w-4xl" : "max-w-lg"} max-h-[90vh] overflow-y-auto p-6`}
                onMouseDown={(e) => e.stopPropagation()}
            >
                <h2 className="text-xl font-bold text-blue-900 mb-4">{title}</h2>
                {children}
            </div>
        </div>
    );
}

const badgeColors = {
    admin: "bg-purple-100 text-purple-700",
    staff: "bg-amber-100 text-amber-700",
    student: "bg-blue-100 text-blue-700",
    Active: "bg-green-100 text-green-700",
    published: "bg-green-100 text-green-700",
    Inactive: "bg-gray-200 text-gray-700",
    inactive: "bg-gray-200 text-gray-700",
    draft: "bg-yellow-100 text-yellow-700",
    Completed: "bg-blue-100 text-blue-700",
    pending: "bg-yellow-100 text-yellow-700",
    approved: "bg-green-100 text-green-700",
    rejected: "bg-red-100 text-red-700",
    cancelled: "bg-gray-200 text-gray-700",
    present: "bg-green-100 text-green-700",
    late: "bg-amber-100 text-amber-700",
    absent: "bg-red-100 text-red-700",
    quiz: "bg-indigo-100 text-indigo-700",
    paper: "bg-teal-100 text-teal-700",
    submitted: "bg-blue-100 text-blue-700",
    graded: "bg-amber-100 text-amber-700",
    closed: "bg-gray-200 text-gray-700",
    started: "bg-yellow-100 text-yellow-700",
};
export function Badge({ children }) {
    return (
        <span className={`text-xs px-2 py-1 rounded-full font-semibold ${badgeColors[children] || "bg-gray-100"}`}>
            {children}
        </span>
    );
}
export const fmtDateTime = (d) =>
    d ? new Date(d.replace(" ", "T")).toLocaleString("en-IN", { day: "2-digit", month: "short", year: "numeric", hour: "2-digit", minute: "2-digit" }) : "—";

export const formatDate = (d) =>
    d ? new Date(d + "T00:00:00").toLocaleDateString("en-IN", { day: "2-digit", month: "short", year: "numeric" }) : "—";
export const formatPrice = (n) => (Number(n) > 0 ? `₹${Number(n).toLocaleString("en-IN")}` : "Free");

export const todayStr = () => {
    const d = new Date();
    return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`;
};
export function StatCard({ label, value }) {
    return (
        <div className="bg-white rounded-xl shadow p-4">
            <p className="text-sm text-gray-500">{label}</p>
            <p className="text-3xl font-bold text-blue-900">{value}</p>
        </div>
    );
}
