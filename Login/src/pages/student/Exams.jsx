import { useEffect, useState } from "react";
import { Link } from "react-router-dom";
import { myExamsApi } from "../../services/api";
import { Alert, Badge, PageHeader, fmtDateTime } from "../../components/ui";

/** Student: every exam assigned to my batches, and what to do next for each. */
function StudentExams() {
    const [rows, setRows] = useState([]);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState("");

    useEffect(() => {
        myExamsApi.list().then((d) => setRows(d.exams)).catch((e) => setError(e.message)).finally(() => setLoading(false));
    }, []);

    const action = (x) => {
        const to = `/my-exams/${x.id}/${x.type === "quiz" ? "take" : "paper"}`;
        const cls = "inline-block bg-blue-900 text-white px-4 py-1.5 rounded-lg font-semibold hover:bg-blue-800";
        if (x.my_status === "published") return <Link to={to} className={cls}>View result</Link>;
        if (x.type === "quiz") {
            if (x.my_status === "submitted") return <Link to={to} className={cls}>View</Link>;
            if (!x.is_open) return <span className="text-sm text-gray-500">{x.not_open_yet ? "Not open yet" : "Closed"}</span>;
            return <Link to={to} className={cls}>{x.my_status === "started" ? "Resume" : "Start"}</Link>;
        }
        if (x.my_status === "pending" && !x.is_open) return <span className="text-sm text-gray-500">{x.not_open_yet ? "Not open yet" : "Closed"}</span>;
        return <Link to={to} className={cls}>{x.my_status === "pending" ? "Open" : "View"}</Link>;
    };

    const label = (x) => (x.my_status === "graded" ? "submitted" : x.my_status); // marks stay hidden until published

    return (
        <div>
            <PageHeader title="My Exams" />
            <Alert>{error}</Alert>
            {loading ? <p>Loading...</p> : rows.length === 0 ? (
                <p className="text-gray-500 bg-white rounded-xl shadow p-4">No exams assigned to you yet.</p>
            ) : (
                <div className="grid md:grid-cols-2 gap-4">
                    {rows.map((x) => (
                        <div key={x.id} className="bg-white rounded-xl shadow p-5 flex flex-col">
                            <div className="flex items-start justify-between gap-2 mb-1">
                                <h2 className="font-semibold text-blue-900">{x.title}</h2>
                                <div className="flex gap-1 shrink-0"><Badge>{x.type}</Badge><Badge>{label(x)}</Badge></div>
                            </div>
                            <p className="text-sm text-gray-500 mb-3">{x.subject || "—"} · by {x.created_by_name}</p>
                            <ul className="text-sm text-gray-600 space-y-1 mb-4">
                                {x.type === "quiz" && <li>{x.question_count} questions{x.duration_minutes ? ` · ${x.duration_minutes} min` : ""}</li>}
                                <li>{x.total_marks} marks</li>
                                {x.end_at && <li>{x.type === "paper" ? "Due" : "Closes"}: {fmtDateTime(x.end_at)}</li>}
                                {x.my_status === "published" && x.marks != null && (
                                    <li className="font-semibold text-green-700">Your marks: {x.marks} / {x.total_marks}</li>
                                )}
                            </ul>
                            <div className="mt-auto">{action(x)}</div>
                        </div>
                    ))}
                </div>
            )}
        </div>
    );
}

export default StudentExams;