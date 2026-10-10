import { useEffect, useState } from "react";
import { Link, useLocation } from "react-router-dom";
import { examsApi } from "../../services/api";
import { getStoredUser } from "../../utils/auth";
import { Alert, Badge, Button, PageHeader, fmtDateTime } from "../../components/ui";

/*
| Exam list for admin + staff.
|   admin -> every exam
|   staff -> only the exams they created
*/
function Exams() {
    const me = getStoredUser();
    const isAdmin = me?.role === "admin";
    const base = isAdmin ? "/admin/exams" : "/staff/exams";
    const location = useLocation();
    const [rows, setRows] = useState([]);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState("");
    const [ok, setOk] = useState(location.state?.ok || "");

    const load = () =>
        examsApi.list().then((d) => setRows(d.exams)).catch((e) => setError(e.message)).finally(() => setLoading(false));

    useEffect(() => { load(); }, []);

    const remove = async (x) => {
        if (!confirm(`Delete "${x.title}"? All student submissions for it will be deleted too.`)) return;
        try { await examsApi.remove(x.id); setOk("Exam deleted"); load(); } catch (e) { setError(e.message); }
    };

    return (
        <div>
            <PageHeader
                title="Exams"
                action={<Link to={`${base}/new`} className="bg-blue-900 text-white px-4 py-2 rounded-lg font-semibold hover:bg-blue-800">+ New exam</Link>}
            />
            <Alert>{error}</Alert>
            <Alert type="success">{ok}</Alert>

            {loading ? <p>Loading...</p> : rows.length === 0 ? (
                <p className="text-gray-500 bg-white rounded-xl shadow p-4">No exams yet. Create an online quiz or a paper exam.</p>
            ) : (
                <div className="bg-white rounded-xl shadow overflow-x-auto">
                    <table className="w-full text-left text-sm">
                        <thead className="bg-gray-50 text-gray-600">
                            <tr>
                                <th className="p-3">Exam</th><th className="p-3">Type</th><th className="p-3">Batches</th>
                                <th className="p-3">Window</th><th className="p-3">Marks</th><th className="p-3">Submitted</th>
                                <th className="p-3">Status</th><th className="p-3 text-right">Actions</th>
                            </tr>
                        </thead>
                        <tbody>
                            {rows.map((x) => (
                                <tr key={x.id} className="border-t align-top">
                                    <td className="p-3">
                                        <p className="font-medium">{x.title}</p>
                                        <p className="text-gray-500">{x.subject || "—"}{isAdmin && x.created_by_name ? ` · by ${x.created_by_name}` : ""}</p>
                                    </td>
                                    <td className="p-3"><Badge>{x.type}</Badge></td>
                                    <td className="p-3">{x.batch_names || "—"}</td>
                                    <td className="p-3 whitespace-nowrap text-gray-600">
                                        {fmtDateTime(x.start_at)}<br />→ {fmtDateTime(x.end_at)}
                                    </td>
                                    <td className="p-3">{x.total_marks}</td>
                                    <td className="p-3 whitespace-nowrap">{x.submitted_count} / {x.assigned_count}</td>
                                    <td className="p-3"><Badge>{x.status}</Badge></td>
                                    <td className="p-3 text-right whitespace-nowrap">
                                        <Link to={`${base}/${x.id}/results`} className="inline-block bg-blue-900 text-white px-3 py-1 rounded-lg font-semibold hover:bg-blue-800 mr-2">
                                            {x.type === "paper" ? "Evaluate" : "Results"}
                                        </Link>
                                        {(isAdmin || Number(x.created_by) === Number(me?.id)) && (
                                            <>
                                                <Link to={`${base}/${x.id}/edit`} className="inline-block bg-gray-200 text-gray-800 px-3 py-1 rounded-lg font-semibold hover:bg-gray-300 mr-2">Edit</Link>
                                                <Button variant="danger" className="!py-1" onClick={() => remove(x)}>Delete</Button>
                                            </>
                                        )}
                                    </td>
                                </tr>
                            ))}
                        </tbody>
                    </table>
                </div>
            )}
        </div>
    );
}

export default Exams;