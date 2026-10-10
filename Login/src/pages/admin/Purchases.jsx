import { useCallback, useEffect, useState } from "react";
import { batchesApi, coursesApi, diagnoseRazorpay, purchasesApi } from "../../services/api";
import { Alert, Button, PageHeader, inputCls } from "../../components/ui";

const money = (n) => `₹${Number(n || 0).toLocaleString("en-IN")}`;

// purchased_at is "YYYY-MM-DD HH:MM:SS" (or null for unpaid orders)
const formatDateTime = (d) =>
    d
        ? new Date(d.replace(" ", "T")).toLocaleString("en-IN", {
              day: "2-digit",
              month: "short",
              year: "numeric",
              hour: "2-digit",
              minute: "2-digit",
          })
        : "—";

const statusColor = {
    paid: "bg-green-100 text-green-700",
    pending: "bg-yellow-100 text-yellow-700",
    failed: "bg-red-100 text-red-700",
};

function Purchases() {
    const [rows, setRows] = useState([]);
    const [summary, setSummary] = useState({ count: 0, students: 0, revenue: 0 });
    const [courses, setCourses] = useState([]);
    const [batches, setBatches] = useState([]);
    const [filter, setFilter] = useState({
        course_id: "",
        batch_id: "",
        status: "paid",
        search: "",
        from: "",
        to: "",
    });
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState("");
    const [diag, setDiag] = useState(null);

    const checkRazorpay = async () => {
        try { setDiag((await diagnoseRazorpay()).checks); } catch (e) { setError(e.message); }
    };

    useEffect(() => {
        coursesApi.list().then((d) => setCourses(d.courses)).catch((e) => setError(e.message));
    }, []);

    // Batch dropdown follows the selected course
    useEffect(() => {
        batchesApi
            .list({ course_id: filter.course_id })
            .then((d) => setBatches(d.batches))
            .catch((e) => setError(e.message));
    }, [filter.course_id]);

    const load = useCallback(async () => {
        try {
            const d = await purchasesApi.list(filter);
            setRows(d.purchases);
            setSummary(d.summary);
            setError("");
        } catch (e) {
            setError(e.message);
        } finally {
            setLoading(false);
        }
    }, [filter]);

    useEffect(() => {
        const t = setTimeout(load, 250);
        return () => clearTimeout(t);
    }, [load]);

    const f = (k) => (e) => {
        const value = e.target.value;
        // changing the course invalidates the chosen batch
        setFilter((cur) => ({ ...cur, [k]: value, ...(k === "course_id" ? { batch_id: "" } : {}) }));
    };

    return (
        <div>
            <PageHeader title="Purchases" action={<Button variant="ghost" onClick={checkRazorpay}>Check Razorpay setup</Button>} />
            {diag && (
                <div className="bg-white rounded-xl shadow p-4 mb-4 text-sm">
                    <p className="font-semibold mb-1">Razorpay check</p>
                    <ul className="space-y-0.5">
                        <li>{diag.curl_extension ? "✅" : "❌"} PHP curl extension</li>
                        <li>{diag.key_id_set ? "✅" : "❌"} Key Id set in backend/config/razorpay.php ({diag.key_mode} mode)</li>
                        <li>{diag.key_secret_set ? "✅" : "❌"} Key Secret set</li>
                        <li>{diag.razorpay_reachable === null ? "⏸" : diag.razorpay_reachable && diag.razorpay_http === 200 ? "✅" : "❌"} Razorpay: {diag.razorpay_message || "not tested yet (fix the items above)"}</li>
                    </ul>
                </div>
            )}
            <Alert>{error}</Alert>

            <div className="grid grid-cols-1 sm:grid-cols-3 gap-4 mb-5">
                <div className="bg-white rounded-xl shadow p-4">
                    <p className="text-sm text-gray-500">Students enrolled</p>
                    <p className="text-2xl font-bold text-blue-900">{summary.students}</p>
                </div>
                <div className="bg-white rounded-xl shadow p-4">
                    <p className="text-sm text-gray-500">Records shown</p>
                    <p className="text-2xl font-bold text-blue-900">{summary.count}</p>
                </div>
                <div className="bg-white rounded-xl shadow p-4">
                    <p className="text-sm text-gray-500">Revenue (paid)</p>
                    <p className="text-2xl font-bold text-green-700">{money(summary.revenue)}</p>
                </div>
            </div>

            <div className="flex gap-3 mb-4 flex-wrap">
                <input
                    className={`${inputCls} max-w-xs`}
                    placeholder="Search student name or email"
                    value={filter.search}
                    onChange={f("search")}
                />
                <select className={`${inputCls} max-w-[220px]`} value={filter.course_id} onChange={f("course_id")}>
                    <option value="">All courses</option>
                    {courses.map((c) => (
                        <option key={c.id} value={c.id}>{c.course_name}</option>
                    ))}
                </select>
                <select className={`${inputCls} max-w-[220px]`} value={filter.batch_id} onChange={f("batch_id")}>
                    <option value="">All batches</option>
                    {batches.map((b) => (
                        <option key={b.id} value={b.id}>{b.batch_name}</option>
                    ))}
                </select>
                <select className={`${inputCls} max-w-[150px]`} value={filter.status} onChange={f("status")}>
                    <option value="paid">Paid</option>
                    <option value="pending">Pending</option>
                    <option value="failed">Failed</option>
                    <option value="all">All</option>
                </select>
                <input type="date" className={`${inputCls} max-w-[160px]`} value={filter.from} onChange={f("from")} title="From date" />
                <input type="date" className={`${inputCls} max-w-[160px]`} value={filter.to} min={filter.from || undefined} onChange={f("to")} title="To date" />
            </div>

            <div className="bg-white rounded-xl shadow overflow-x-auto">
                <table className="w-full text-left text-sm">
                    <thead className="bg-gray-50 text-gray-600">
                        <tr>
                            <th className="p-3">Student</th>
                            <th className="p-3">Course</th>
                            <th className="p-3">Batch</th>
                            <th className="p-3">Amount</th>
                            <th className="p-3">Status</th>
                            <th className="p-3">Date</th>
                            <th className="p-3">Payment ID</th>
                        </tr>
                    </thead>
                    <tbody>
                        {loading && (
                            <tr><td className="p-4" colSpan="7">Loading...</td></tr>
                        )}
                        {!loading && rows.length === 0 && (
                            <tr><td className="p-4 text-gray-500" colSpan="7">No purchases found</td></tr>
                        )}
                        {rows.map((r) => (
                            <tr key={r.id} className="border-t">
                                <td className="p-3">
                                    <p className="font-medium">{r.student_name}</p>
                                    <p className="text-gray-500">{r.student_email}</p>
                                </td>
                                <td className="p-3">{r.course_name}</td>
                                <td className="p-3">{r.batch_name || "—"}</td>
                                <td className="p-3 whitespace-nowrap">{r.amount > 0 ? money(r.amount) : "Free"}</td>
                                <td className="p-3">
                                    <span className={`text-xs px-2 py-1 rounded-full font-semibold ${statusColor[r.status] || "bg-gray-100"}`}>
                                        {r.status}
                                    </span>
                                </td>
                                <td className="p-3 whitespace-nowrap">{formatDateTime(r.purchased_at)}</td>
                                <td className="p-3 text-xs text-gray-500">{r.payment_id || "—"}</td>
                            </tr>
                        ))}
                    </tbody>
                </table>
            </div>
        </div>
    );
}

export default Purchases;
