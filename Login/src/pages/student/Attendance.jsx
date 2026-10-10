import { useEffect, useState } from "react";
import { Link } from "react-router-dom";
import { studentApi } from "../../services/api";
import { Alert, Badge, PageHeader, formatDate } from "../../components/ui";

function StudentAttendance() {
    const [batches, setBatches] = useState([]);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState("");

    useEffect(() => {
        studentApi.attendance().then((d) => setBatches(d.batches)).catch((e) => setError(e.message)).finally(() => setLoading(false));
    }, []);

    return (
        <div>
            <PageHeader title="My Attendance" action={<Link to="/my-leaves" className="text-blue-700 font-semibold">Apply for leave →</Link>} />
            <Alert>{error}</Alert>
            {loading && <p>Loading...</p>}
            {!loading && batches.length === 0 && <p className="text-gray-500">Attendance appears here once you join a batch.</p>}

            {batches.map((b) => (
                <div key={b.id} className="mb-8">
                    <h2 className="text-lg font-bold text-blue-900">{b.batch_name} <span className="text-gray-500 font-normal text-sm">· {b.course_name}</span></h2>

                    <div className="bg-white rounded-xl shadow overflow-x-auto mt-2">
                        <table className="w-full text-left text-sm">
                            <thead className="bg-gray-50 text-gray-600">
                                <tr><th className="p-3">Subject</th><th className="p-3">Staff</th><th className="p-3">Present</th><th className="p-3">Late</th><th className="p-3">Absent</th><th className="p-3">Attendance</th></tr>
                            </thead>
                            <tbody>
                                {b.subjects.length === 0 && <tr><td className="p-4 text-gray-500" colSpan="6">No subjects assigned yet</td></tr>}
                                {b.subjects.map((s) => (
                                    <tr key={s.id} className="border-t">
                                        <td className="p-3 font-medium">{s.subject_name}</td>
                                        <td className="p-3">{s.staff_name}</td>
                                        <td className="p-3">{s.present}</td><td className="p-3">{s.late}</td><td className="p-3">{s.absent}</td>
                                        <td className="p-3">{s.percent === null ? "—" : `${s.percent}%`}</td>
                                    </tr>
                                ))}
                            </tbody>
                        </table>
                    </div>

                    {b.records.length > 0 && (
                        <details className="mt-2">
                            <summary className="cursor-pointer text-blue-700 text-sm font-semibold">Recent days</summary>
                            <div className="bg-white rounded-xl shadow mt-2 divide-y">
                                {b.records.map((r, i) => (
                                    <div key={i} className="p-2.5 flex justify-between text-sm">
                                        <span>{formatDate(r.attendance_date)} · {r.subject_name}</span>
                                        <Badge>{r.status}</Badge>
                                    </div>
                                ))}
                            </div>
                        </details>
                    )}
                </div>
            ))}
        </div>
    );
}

export default StudentAttendance;
