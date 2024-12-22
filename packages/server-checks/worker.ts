const notify = (env, msg) => fetch(env.webhookUrl+"?wait=true", { method: "POST", body: JSON.stringify({ content: msg }), headers: { "content-type": "application/json" } });

const machinesToCheck = [
	"edge-vlsto-4622d8e3",
	"edge-vlsto-4622d978",
	"hashi-hchel1-251b08ea",
	"hashi-hchel1-5fd89a52",
	"hashi-hchel1-5fd9b1fe",
	"database-hrhel1-b959773f",
	"compute-hrhel1-3c45e932",
	"compute-hrhel1-70e1bd12",
	"compute-hchel1-416cf81b",
];

async function processMachine(env, m, silences, notifRole) {
	let mdata;

	if (!!silences.find(x => x.checkPrefix == "*" && x.node == m )) {
		console.log(`machine ${m} is silenced, skipping`);
		return;
	}

	notifRole = notifRole ?? "<@&1291763746657669211>";

	try {
		let hostname = `${m}.prod.pluralkit.net`;
		mdata = await fetch(`http://${hostname}:19999/checks`);
		mdata = await mdata.json();
	} catch(e) {
		await notify(env, `${notifRole}, on ${m}: failed to query checks status: ${e}`);
		return;
	}

	let out = [];

	if (isNaN(mdata.ts)) {
		out.push("- could not find last check timestamp");
	} else if (mdata.ts < (Date.now() / 1000 - 90)) {
		out.push(`- last check is too old (${mdata.ts - Date.now() / 1000} seconds ago)`);
	}

	if (!Array.isArray(mdata.errors)) {
		out.push("- could not find errors array");
	} else if (mdata.errors.length > 0) {
		let errors = mdata.errors.filter(e => !silences.find(x => (x.node == m || x.node == "*") && (e == x.check || e.startsWith(x.checkPrefix))));
		if (errors.length != mdata.errors.length) console.log("some errors silenced on "+m);
		out.unshift(...errors.map(e => `- ${e}`));
	}

	if (out.length > 0) await notify(env, `${notifRole}, on ${m}:\n${out.join("\n")} \n`);
	else console.log(`${m}: all checks ok!`);
}

export default {
	async scheduled(request, env, ctx): Promise<Response> {
// test
//		console.log(JSON.stringify(await notify(env, "test").then(x => x.json())));

		let silences = await env.kv.get("silences").then(x => JSON.parse(x));
//			JSON.parse(x).map(x => ({ check: x.split("@")[0], node: x.split("@")[1] }))
//					.map(x => {
//						if (x.check.endsWith("*")) {
//							x.checkPrefix = x.check[x.check.length - 1];
//							x.check == null;
//						}
//						return x;
//					})
//			);

		let notifRole = await env.kv.get("notif");
		if (notifRole == "") notifRole = null;

		await Promise.all(machinesToCheck.map(m => processMachine(env, m, silences, notifRole)))

		console.log("cron processed!");
	},
} satisfies ExportedHandler<Env>;
